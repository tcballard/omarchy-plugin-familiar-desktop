-- Scoped editing aliases, not a global Super/Control swap. Reload restores
-- original bindings when the owned include is removed.
local terminals = {
  ['kitty']=true, ['alacritty']=true, ['foot']=true, ['footclient']=true,
  ['org.wezfurlong.wezterm']=true, ['wezterm']=true,
  ['com.mitchellh.ghostty']=true, ['ghostty']=true,
  ['org.gnome.terminal']=true, ['gnome-terminal-server']=true,
  ['org.kde.konsole']=true, ['konsole']=true, ['xterm']=true,
  ['urxvt']=true, ['st']=true, ['terminator']=true, ['tilix']=true,
}
local shortcuts = {
  {key='C', name='Copy'}, {key='V', name='Paste'},
  {key='X', name='Cut'}, {key='A', name='Select all'},
  {key='Z', name='Undo'}, {key='Z', shift=true, name='Redo'},
}
for _, entry in ipairs(shortcuts) do
  local key, shift, name = entry.key, entry.shift, entry.name
  local chord = (shift and 'SUPER + SHIFT + ' or 'SUPER + ') .. key
  hl.unbind(chord)
  hl.bind(chord, function()
    local window = hl.get_active_window()
    if not window then return end
    local class = string.lower(window.initial_class or window.class or '')
    local terminal = terminals[class] or class:find('terminal', 1, true)
    if terminal and (shift or (key ~= 'C' and key ~= 'V')) then
      return {pass_event=true}
    end
    local mods = (terminal or shift) and 'CTRL SHIFT' or 'CTRL'
    return hl.dsp.send_shortcut({mods=mods, key=key, window=window})()
  end, {description='Familiar Command: ' .. name})
end
