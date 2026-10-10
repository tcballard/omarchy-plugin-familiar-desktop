-- Capture the generated callbacks, then execute them using real Hyprland
-- dispatchers and timers against the disposable account's active window.
local callbacks = {}
local bind, unbind = hl.bind, hl.unbind
hl.bind = function(chord, action) callbacks[chord] = action end
hl.unbind = function() end
local ok, message = pcall(dofile, os.getenv('HOME') .. '/.config/omarchy/familiar-input/command.lua')
hl.bind, hl.unbind = bind, unbind
assert(ok, message)
assert(callbacks['SUPER + C'] and callbacks['SUPER + V'])
-- Copy would interrupt the fixture terminal's foreground sleep.
for _, chord in ipairs({'SUPER + V', 'SUPER + A', 'SUPER + SHIFT + Z'}) do
  callbacks[chord]()
end
