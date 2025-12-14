module UiHelper
  PAGE_SHELL_CLASS = "mx-auto max-w-6xl px-4 py-8".freeze
  CARD_BASE_CLASS = "rounded-2xl p-4 shadow-sm ring-1".freeze

  BUTTON_SIZES = {
    sm: "px-3 py-1 text-xs",
    md: "px-4 py-2 text-sm",
    lg: "px-5 py-3 text-base"
  }.freeze

  BUTTON_VARIANTS = {
    primary: "bg-emerald-600 text-white hover:bg-emerald-500 focus:ring-emerald-500",
    secondary: "bg-gray-900 text-white hover:bg-gray-800 focus:ring-gray-900",
    outline: "border border-gray-300 bg-white text-gray-700 hover:bg-gray-50 focus:ring-gray-400",
    danger: "bg-rose-600 text-white hover:bg-rose-500 focus:ring-rose-500"
  }.freeze

  def page_shell(&block)
    content_tag(:div, capture(&block), class: PAGE_SHELL_CLASS)
  end

  def card(variant: :default, classes: "", &block)
    palette = {
      default: "bg-white ring-gray-200",
      muted: "bg-gray-50 ring-gray-200",
      warning: "bg-rose-50 ring-rose-200",
      success: "bg-emerald-50 ring-emerald-200"
    }
    css = [CARD_BASE_CLASS, palette.fetch(variant, palette[:default]), classes].compact.join(" ")
    content_tag(:div, capture(&block), class: css)
  end

  def button_classes(variant: :primary, size: :md)
    [
      "inline-flex items-center rounded-lg font-semibold focus:outline-none focus:ring-2 focus:ring-offset-2 shadow-sm",
      BUTTON_SIZES.fetch(size, BUTTON_SIZES[:md]),
      BUTTON_VARIANTS.fetch(variant, BUTTON_VARIANTS[:primary])
    ].join(" ")
  end

  def table_header_class(extra = "")
    "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-600 #{extra}".strip
  end

  def table_cell_class(extra = "", align: :left, tone: :default)
    text_color = case tone
                 when :muted then "text-gray-600"
                 when :success then "text-emerald-700"
                 when :danger then "text-rose-700"
                 when :info then "text-blue-700"
                 else "text-gray-900"
                 end

    align_class = align == :right ? "text-right" : ""
    "px-4 py-3 text-sm #{text_color} #{align_class} #{extra}".strip
  end

  def badge(text, tone: :info)
    palette = {
      info: "bg-blue-50 text-blue-700",
      danger: "bg-rose-50 text-rose-700",
      success: "bg-emerald-50 text-emerald-700",
      warning: "bg-amber-50 text-amber-700"
    }
    content_tag(:span, text,
                class: "inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold #{palette.fetch(tone, palette[:info])}")
  end
end
