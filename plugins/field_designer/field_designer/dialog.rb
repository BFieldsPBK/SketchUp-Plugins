# Thin wrapper around UI::HtmlDialog, following the office HtmlDialog
# pattern: callbacks receive a single JSON payload from the page and hand
# the parsed hash to the registered block.

require "json"

module FieldDesigner
  class Dialog
    def initialize(key:, title:, html:, width: 420, height: 560)
      @dialog = UI::HtmlDialog.new(
        dialog_title: title,
        preferences_key: "FieldDesigner_#{key}",
        style: UI::HtmlDialog::STYLE_DIALOG,
        width: width,
        height: height,
        resizable: true
      )
      @dialog.set_file(File.join(FieldDesigner::RESOURCES, "html", html))
    end

    def on(action, &block)
      @dialog.add_action_callback(action) do |_ctx, payload|
        data = payload.to_s.strip.empty? ? {} : JSON.parse(payload)
        block.call(data)
      end
      self
    end

    def show
      @dialog.show
      self
    end

    def close
      @dialog.close
    end
  end

  # Show the (single) field generator dialog.
  def self.run
    @dialog = Dialog.new(key: "field", title: "Field Generator",
                         html: "field_dialog.html")
    @dialog.on("generate") do |data|
      @dialog.close
      Generator.build(data)
    end
    @dialog.on("cancel") { @dialog.close }
    @dialog.show
  end
end
