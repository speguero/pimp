
-- autosave.lua
-- ------------
-- 
-- periodically saves watch_later data during mpv playback.
-- accounts for periodic cached write synchronization on raspberry pi.

os        = require 'os'
mp        = require 'mp'
mp_opt    = require 'mp.options'
timer_opt = {save_period = 15} -- seconds per mpv watch_later cache save.
raspi     = false

function platform()

	-- gets running platform / os.

	local out = io.popen('uname -s')
	local sys = out:read '*line'

	io.close(out)
	return sys:lower()
end

function raspi_write_sync()

	-- synchronizes watch_later cache to raspberry pi storage device.
	
	local f = nil
	
	if raspi == true then
		os.execute('sync')
		return true
	end

	-- raspberry pi os:
	if platform() == 'linux' then
		f = io.open('/sys/firmware/devicetree/base/model', 'r')
	end

	if f ~= nil then
		str = f:read '*a'
		io.close(f)
	else
		return false
	end

	if string.match(str, '^Raspberry Pi') then
		raspi = true
		os.execute('sync')
		return true
	else
		return false
	end
end

function add_wl()
	mp.commandv('write-watch-later-config')
	raspi_write_sync()
end

function del_wl(data)
	if data.reason == 'eof' or data.reason == 'stop' then
		local playlist = mp.get_property_native('playlist')
		
		for i, entry in pairs(playlist) do
			if entry.id == data.playlist_entry_id then
				mp.commandv('delete-watch-later-config', entry.filename)
				raspi_write_sync()
			end
		end
	end
end

mp_opt.read_options(timer_opt)
save_period_timer = mp.add_periodic_timer(timer_opt.save_period, add_wl)

mp.register_event('file-loaded', add_wl)
mp.register_event('start-file',  add_wl)
mp.register_event('end-file',    del_wl)
