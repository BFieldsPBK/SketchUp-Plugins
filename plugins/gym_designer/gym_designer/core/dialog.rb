# Thin wrapper around UI::HtmlDialog shared by both tools.
#
# Callbacks receive a single JSON payload from the page and hand the parsed
# hash to the registered block. The page calls `sketchup.ready()` on load;
# if prefill data was set, it is pushed back via a `prefill(data)` JS
# function the page defines.

require "json"

module GymDesigner
  module Core
    class Dialog
      def initialize(key:, title:, html:, width: 460, height: 640)
        @dialog = UI::HtmlDialog.new(
          dialog_title: title,
          preferences_key: "GymDesigner_#{key}",
          style: UI::HtmlDialog::STYLE_DIALOG,
          width: width,
          height: height,
          resizable: true
        )
        @dialog.set_file(File.join(GymDesigner::RESOURCES, "html", html))
        @dialog.add_action_callback("ready") { |_ctx, _payload| push_prefill }
      end

      def on(action, &block)
        @dialog.add_action_callback(action) do |_ctx, payload|
          data = payload.to_s.strip.empty? ? {} : JSON.parse(payload)
          block.call(data)
        end
        self
      end

      def prefill(data)
        @prefill = data
        self
      end

      def show
        @dialog.show
        self
      end

      def close
        @dialog.close
      end

      private

      def push_prefill
        return unless @prefill
        @dialog.execute_script("window.prefill && window.prefill(#{JSON.generate(@prefill)});")
      end
    end
  end
end
