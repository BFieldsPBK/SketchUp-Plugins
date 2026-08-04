# frozen_string_literal: true

require 'json'

module BSF
  module ProgramTranslator
    # The review/configuration dialog shown after a CSV is parsed. It lists
    # every room *type* with a single side-dimension field (applied to all
    # rooms of that type; blank keeps the square default) and an editable
    # color swatch per department, seeded from the spreadsheet palette.
    #
    # Usage:
    #   Dialog.show(program) { |config| Builder.build(program, config) }
    module Dialog
      module_function

      def show(program, &on_generate)
        dlg = UI::HtmlDialog.new(
          dialog_title: 'Import Program',
          preferences_key: 'bsf_program_translator',
          width: 860, height: 640, min_width: 560,
          style: UI::HtmlDialog::STYLE_DIALOG
        )
        dlg.set_html(html(program))

        dlg.add_action_callback('generate') do |_ctx, payload|
          config = parse_payload(payload)
          dlg.close
          begin
            n = on_generate.call(config)
            UI.messagebox("Created #{n} room blocks.") if n
          rescue StandardError => e
            UI.messagebox("Import failed: #{e.message}")
          end
        end
        dlg.add_action_callback('cancel') { dlg.close }

        dlg.center
        dlg.show
        dlg
      end

      def parse_payload(payload)
        data = JSON.parse(payload)
        {
          colors: (data['colors'] || {}).transform_values { |h| h.sub(/\A#/, '') },
          rooms:  data['rooms'] || {}
        }
      end

      # ---- HTML ----------------------------------------------------------

      def html(program)
        data = program[:departments].map.with_index do |dept, di|
          {
            'di' => di, 'name' => dept[:name], 'color' => "##{dept[:color]}",
            'rooms' => dept[:line_items].map.with_index do |room, ri|
              { 'ri' => ri, 'name' => room[:name], 'count' => room[:count],
                'sf' => room[:sf_per_room], 'side' => room[:default_side] }
            end
          }
        end
        <<~HTML
          <!DOCTYPE html>
          <html><head><meta charset="utf-8"><style>
            body { font: 13px/1.4 "Segoe UI", Arial, sans-serif; margin: 0;
                   color: #222; }
            header { position: sticky; top: 0; background: #fff;
                     padding: 12px 16px; border-bottom: 1px solid #ddd; }
            h1 { font-size: 15px; margin: 0 0 4px; }
            p.hint { margin: 0; color: #666; font-size: 12px; }
            .wrap { padding: 8px 16px 80px; }
            .dept { margin-top: 16px; border: 1px solid #e2e2e2;
                    border-radius: 6px; overflow: hidden; }
            .dept-head { display: flex; align-items: center; gap: 8px;
                         padding: 8px 10px; background: #f6f6f6;
                         border-bottom: 1px solid #e2e2e2; }
            .dept-head strong { flex: 1; }
            table { width: 100%; border-collapse: collapse; }
            td, th { padding: 5px 10px; text-align: left; font-size: 12px; }
            th { color: #888; font-weight: 600; border-bottom: 1px solid #eee; }
            tr:nth-child(even) td { background: #fafafa; }
            input[type=number] { width: 64px; }
            .depth { color: #666; }
            footer { position: fixed; bottom: 0; left: 0; right: 0;
                     background: #fff; border-top: 1px solid #ddd;
                     padding: 10px 16px; text-align: right; }
            button { font-size: 13px; padding: 7px 16px; margin-left: 8px;
                     border-radius: 5px; border: 1px solid #bbb;
                     cursor: pointer; }
            button.primary { background: #1a73e8; color: #fff;
                             border-color: #1a73e8; }
          </style></head>
          <body>
            <header>
              <h1>Program &rarr; Model</h1>
              <p class="hint">Edit <b>Area</b> to change a room's SF. Tick
                <b>Square</b> to make it square (area sets both sides); untick
                to type one side in feet (area sets the other). Set each
                room's <b>Height</b>, and adjust department colors as needed.</p>
              <p class="hint">
                <label><input type="checkbox" id="all_square" checked
                  onchange="setAllSquare(this.checked)"> Make all rooms
                  square</label>
                &nbsp;&nbsp;&bull;&nbsp;&nbsp;
                <label>Default height (ft):
                  <input type="number" id="def_height" value="10" min="1"
                    step="0.5" onchange="setAllHeights(this.value)"></label>
              </p>
            </header>
            <div class="wrap" id="wrap"></div>
            <footer>
              <button onclick="cancel()">Cancel</button>
              <button class="primary" onclick="generate()">Generate</button>
            </footer>
            <script>
              var DATA = #{JSON.generate(data)};

              function el(p, di, ri) {
                return document.getElementById(p + '_' + di + '_' + ri);
              }
              function squareSide(sf) { return Math.sqrt(sf); }
              function isSquare(di, ri) { return el('sq', di, ri).checked; }
              // Current (possibly edited) area for a room, in SF.
              function getSf(di, ri) {
                var v = parseFloat(el('sf', di, ri).value);
                return (v && v > 0) ? v : 0;
              }
              function depthFor(sf, side) {
                side = parseFloat(side);
                if (!side || side <= 0) side = squareSide(sf);
                if (!sf || !side) return '0.0';
                return (sf / side).toFixed(1);
              }
              // Refresh the "other side" readout (and, when square, the side).
              function recompute(di, ri) {
                var sf = getSf(di, ri);
                if (isSquare(di, ri)) el('side', di, ri).value =
                  squareSide(sf).toFixed(1);
                el('depth', di, ri).textContent =
                  depthFor(sf, el('side', di, ri).value) + ' ft';
              }
              function onSf(di, ri) { recompute(di, ri); }
              // Toggle a single room between square and a custom side.
              function toggleSquare(di, ri) {
                var inp = el('side', di, ri), sf = getSf(di, ri);
                if (isSquare(di, ri)) {
                  inp.dataset.custom = inp.value;        // remember custom side
                  inp.disabled = true;
                } else {
                  inp.disabled = false;
                  inp.value = inp.dataset.custom || Math.round(squareSide(sf));
                  inp.focus();
                }
                syncMaster();
                recompute(di, ri);
              }
              function setAllSquare(on) {
                DATA.forEach(function (d) {
                  d.rooms.forEach(function (r) {
                    var box = el('sq', d.di, r.ri);
                    if (box.checked !== on) {
                      box.checked = on;
                      toggleSquare(d.di, r.ri);
                    }
                  });
                });
              }
              function setAllHeights(v) {
                DATA.forEach(function (d) {
                  d.rooms.forEach(function (r) { el('ht', d.di, r.ri).value = v; });
                });
              }
              // Keep the master checkbox in sync with the row checkboxes.
              function syncMaster() {
                var all = true;
                DATA.forEach(function (d) {
                  d.rooms.forEach(function (r) {
                    if (!isSquare(d.di, r.ri)) all = false;
                  });
                });
                document.getElementById('all_square').checked = all;
              }
              function render() {
                var html = "";
                DATA.forEach(function (d) {
                  html += '<div class="dept"><div class="dept-head">' +
                    '<input type="color" id="color_' + d.di + '" value="' +
                    d.color + '">' +
                    '<strong>' + d.name + '</strong>' +
                    '<span class="depth">' + d.rooms.length +
                    ' room type(s)</span></div>' +
                    '<table><tr><th>Room</th><th>Qty</th><th>Area (SF)</th>' +
                    '<th>Square</th><th>Side (ft)</th><th>Other side</th>' +
                    '<th>Height (ft)</th></tr>';
                  d.rooms.forEach(function (r) {
                    var p = d.di + ',' + r.ri;
                    html += '<tr><td>' + r.name + '</td><td>' + r.count + '</td>' +
                      '<td><input type="number" min="1" step="1" id="sf_' +
                      d.di + '_' + r.ri + '" value="' + r.sf +
                      '" oninput="onSf(' + p + ')"></td>' +
                      '<td><input type="checkbox" id="sq_' + d.di + '_' + r.ri +
                      '" checked onchange="toggleSquare(' + p + ')"></td>' +
                      '<td><input type="number" min="1" step="0.5" id="side_' +
                      d.di + '_' + r.ri + '" value="' +
                      squareSide(r.sf).toFixed(1) + '" disabled' +
                      ' oninput="recompute(' + p + ')"></td>' +
                      '<td class="depth" id="depth_' + d.di + '_' + r.ri +
                      '">' + depthFor(r.sf, '') + ' ft</td>' +
                      '<td><input type="number" min="1" step="0.5" id="ht_' +
                      d.di + '_' + r.ri + '" value="10"></td></tr>';
                  });
                  html += '</table></div>';
                });
                document.getElementById('wrap').innerHTML = html;
              }
              function generate() {
                var rooms = {}, colors = {};
                DATA.forEach(function (d) {
                  colors['' + d.di] =
                    document.getElementById('color_' + d.di).value;
                  d.rooms.forEach(function (r) {
                    var side = isSquare(d.di, r.ri) ? null :
                      parseFloat(el('side', d.di, r.ri).value);
                    var ht = parseFloat(el('ht', d.di, r.ri).value);
                    rooms[d.di + '_' + r.ri] = {
                      sf: getSf(d.di, r.ri),
                      side: (side && side > 0) ? side : null,
                      height: (ht && ht > 0) ? ht : null
                    };
                  });
                });
                sketchup.generate(JSON.stringify({colors: colors, rooms: rooms}));
              }
              function cancel() { sketchup.cancel(); }
              render();
            </script>
          </body></html>
        HTML
      end
    end
  end
end
