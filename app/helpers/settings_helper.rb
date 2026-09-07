module SettingsHelper
  SETTINGS_ORDER = [
    { key: "profile", path: :settings_profile_path },
    { key: "preferences", path: :settings_preferences_path },
    { key: "security", path: :settings_security_path },
    { key: "self_hosting", path: :settings_hosting_path, condition: :self_hosted? },
    { key: "api_key", path: :settings_api_key_path },
    { key: "billing", path: :settings_billing_path, condition: :not_self_hosted? },
    { key: "accounts", path: :accounts_path },
    { key: "imports", path: :imports_path },
    { key: "tags", path: :tags_path },
    { key: "categories", path: :categories_path },
    { key: "rules", path: :rules_path },
    { key: "merchants", path: :family_merchants_path },
    { key: "whats_new", path: :changelog_path },
    { key: "feedback", path: :feedback_path }
  ]

  def adjacent_setting(current_path, offset)
    visible_settings = SETTINGS_ORDER.select { |setting| setting[:condition].nil? || send(setting[:condition]) }
    current_index = visible_settings.index { |setting| send(setting[:path]) == current_path }
    return nil unless current_index

    adjacent_index = current_index + offset
    return nil if adjacent_index < 0 || adjacent_index >= visible_settings.size

    adjacent = visible_settings[adjacent_index]

    render partial: "settings/settings_nav_link_large", locals: {
      path: send(adjacent[:path]),
      direction: offset > 0 ? "next" : "previous",
      title: I18n.t("settings.settings_nav.#{adjacent[:key]}_label")
    }
  end

  def settings_section(title:, subtitle: nil, &block)
    content = capture(&block)
    render partial: "settings/section", locals: { title: title, subtitle: subtitle, content: content }
  end

  def settings_nav_footer
    previous_setting = adjacent_setting(request.path, -1)
    next_setting = adjacent_setting(request.path, 1)

    content_tag :div, class: "hidden md:flex flex-row justify-between gap-4" do
      concat(previous_setting)
      concat(next_setting)
    end
  end

  def settings_nav_footer_mobile
    previous_setting = adjacent_setting(request.path, -1)
    next_setting = adjacent_setting(request.path, 1)

    content_tag :div, class: "md:hidden flex flex-col gap-4" do
      concat(previous_setting)
      concat(next_setting)
    end
  end

  private
    def not_self_hosted?
      !self_hosted?
    end
end
