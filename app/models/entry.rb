class Entry < ApplicationRecord
  include Monetizable, Enrichable

  monetize :amount

  belongs_to :account
  belongs_to :transfer, optional: true
  belongs_to :import, optional: true

  has_many :entry_splits, dependent: :destroy
  has_many :split_categories, through: :entry_splits, source: :category
  accepts_nested_attributes_for :entry_splits, allow_destroy: true, reject_if: :all_blank

  has_many :reimbursement_links_as_expense, class_name: "ReimbursementLink", foreign_key: :expense_entry_id, dependent: :destroy
  has_many :reimbursement_links_as_income, class_name: "ReimbursementLink", foreign_key: :income_entry_id, dependent: :destroy
  has_many :reimbursing_entries, through: :reimbursement_links_as_expense, source: :income_entry
  has_many :reimbursed_entries, through: :reimbursement_links_as_income, source: :expense_entry

  delegated_type :entryable, types: Entryable::TYPES, dependent: :destroy
  accepts_nested_attributes_for :entryable

  validates :date, :name, :amount, :currency, presence: true
  validates :date, uniqueness: { scope: [ :account_id, :entryable_type ] }, if: -> { valuation? }
  validates :date, comparison: { greater_than: -> { min_supported_date } }
  validate :splits_sum_matches_amount, if: -> { entry_splits.any? }

  scope :visible, -> {
    joins(:account).where(accounts: { status: [ "draft", "active" ] })
  }

  scope :chronological, -> {
    order(
      date: :asc,
      Arel.sql("CASE WHEN entries.entryable_type = 'Valuation' THEN 1 ELSE 0 END") => :asc,
      created_at: :asc
    )
  }

  scope :reverse_chronological, -> {
    order(
      date: :desc,
      Arel.sql("CASE WHEN entries.entryable_type = 'Valuation' THEN 1 ELSE 0 END") => :desc,
      created_at: :desc
    )
  }

  def classification
    amount.negative? ? "income" : "expense"
  end

  def split?
    entry_splits.loaded? ? entry_splits.any? : entry_splits.exists?
  end

  def reimbursement?
    reimbursement_links_as_income.loaded? ? reimbursement_links_as_income.any? : reimbursement_links_as_income.exists?
  end

  def lock_saved_attributes!
    super
    entryable.lock_saved_attributes!
  end

  def sync_account_later
    sync_start_date = [ date_previously_was, date ].compact.min unless destroyed?
    account.sync_later(window_start_date: sync_start_date)
  end

  def entryable_name_short
    entryable_type.demodulize.underscore
  end

  def balance_trend(entries, balances)
    Balance::TrendCalculator.new(self, entries, balances).trend
  end

  def linked?
    plaid_id.present?
  end

  class << self
    def search(params)
      EntrySearch.new(params).build_query(all)
    end

    # arbitrary cutoff date to avoid expensive sync operations
    def min_supported_date
      30.years.ago.to_date
    end

    def bulk_update!(bulk_update_params)
      bulk_attributes = {
        date: bulk_update_params[:date],
        notes: bulk_update_params[:notes],
        entryable_attributes: {
          category_id: bulk_update_params[:category_id],
          merchant_id: bulk_update_params[:merchant_id],
          tag_ids: bulk_update_params[:tag_ids]
        }.compact_blank
      }.compact_blank

      return 0 if bulk_attributes.blank?

      transaction do
        all.each do |entry|
          bulk_attributes[:entryable_attributes][:id] = entry.entryable_id if bulk_attributes[:entryable_attributes].present?
          entry.update! bulk_attributes

          entry.lock_saved_attributes!
          entry.entryable.lock_attr!(:tag_ids) if entry.transaction? && entry.transaction.tags.any?
        end
      end

      all.size
    end
  end

  private

    def splits_sum_matches_amount
      splits_total = entry_splits.reject(&:marked_for_destruction?).sum(&:amount)
      unless splits_total.round(4) == amount.round(4)
        errors.add(:entry_splits, :sum_mismatch,
          message: I18n.t("errors.entry_splits.sum_mismatch",
            splits_total: splits_total,
            entry_amount: amount))
      end
    end
end
