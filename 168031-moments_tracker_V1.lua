
 function descriptor()
    return {
       title = "Moments Tracker",
       version = "1.0",
       author = "ARahman Rashed",
       url = 'http://aur-tech.blogspot.com',
       shortdesc = "Bookmark your moments",
       description = "",
       capabilities = {"menu", "input-listener", "meta-listener", "playing-listener"}
    }
 end

 -------------- Global variables -------------
 checkpoints = {}
 moments = {}
 -- holds checkpoints' metadata (date,time,etc..)
 checkpoints_meta = {}
 -- path to the file where checkpoints and moments are saved
 destination = nil
 media_name = nil
 media_duration = nil
-----------------------------------------------
 

 -- helper function to copy array elements by value
 function shallow_copy(t) 
   local t2 = {}
   for k,v in pairs(t) do
     t2[k] = v
   end
   return t2
 end
 
 function get_media_meta()
  input = vlc.object.input()
  media_name = vlc.input.item():name()
  media_duration = vlc.input.item():duration()
 end

 function display_error_box()
 error_dialog = vlc.dialog("As if life isn't harsh enough")
 error_dialog:add_label("Ummm..please open a media file before switching on the extension and restart VLC")
 end

 function activate()
  vlc.msg.dbg(vlc.config.userdatadir())
  if pcall(get_media_meta) then
   get_media_meta() 
   -- destination = vlc.config.userdatadir().."/moments_tracker.txt"
   item_uri = vlc.input.item():uri()
   destination = item_uri:sub(8,item_uri:len()) .. ".bookmarks" -- got substring in order to get rid of "file://"
   
   load_checkpoints_moments() 
   createGUI()
   display_moments()
  else display_error_box()
  end
 end

 function createGUI()
   main_layout = vlc.dialog("Moments and checkpoints tracker")
   main_layout:add_label("<b>Moments for this media :</b>",1,3)  
   moments_list = main_layout:add_list(1,4,4,1)
   capture_moment_b = main_layout:add_button(" Capture Moment ",capture_moment,1, 5, 1, 1)
   remove_moment_b = main_layout:add_button(" Remove Moment ",remove_moment,3,5,1,1)
   go_to_moment_b = main_layout:add_button(" Jump to Moment ",jump_to_moment,2,5,1,1)
   main_layout:add_label("<hr>",1,6,5,1)
   main_layout:add_label("<b>Track Checkpoints :</b>",1,6,5,1)
   checkpoint_l = main_layout:add_label("",2,7)
   display_checkpoint_data() 
   mark_position_b = main_layout:add_button(" Checkpoint! ", mark_position, 1,8,1,1)
   go_to_checkpoint_b = main_layout:add_button(" Retrieve Checkpoint ", jump_to_checkpoint, 2,8,1,1)
 end

function display_checkpoint_data()
if checkpoints_meta[media_name][1]~=nil then 
      checkpoint_l:set_text("")
      checkpoint_l:set_text("<i>last checkpoint : "..checkpoints_meta[media_name][1].." @ "..checkpoints_meta[media_name][2].."</i>")
   else checkpoint_l:set_text("<i>No checkpoints marked for this media</i>")
 end
end

 function save_checkpoints_moments(s)
 file= io.open(destination,"w")
 for i,j in pairs(s) do
   file:write(i,"~",j,"~",checkpoints_meta[i][1],"~",checkpoints_meta[i][2],"\n")
   if moments[i] ~= nil and next(moments[i]) ~= nil then
    for a,b in pairs(moments[i]) do
     file:write(a,"~",b,"*&")
    end
   else file:write("nil")
   end
   file:write("\n")
  end
  file:flush()
   file:close() 
 end

 function load_checkpoints_moments()
 local i=0
 local temp_name = ""
 temp_moments ={} 
 checkpoints_meta[media_name] = {}
 file = io.open(destination,w)
 if (file) then
  for line in file:lines() do
    if line ~= nil then
     if i%2 == 0 then -- parse checkpoints  
       for k,v,ch1,ch2 in string.gmatch(line,"(%w.+)~(%w.+)~(%w.+)~(%w.+)") do
         checkpoints[k] = v
         temp_name = k
		 checkpoints_meta[k] = {}
		 checkpoints_meta[k][1] = ch1
		 checkpoints_meta[k][2] = ch2
        end
     elseif line~="nil" then       -- if mod
        itr = string.gmatch(line, '([^(*&)]+)')
        for chunks in itr do
          for a,b in string.gmatch(chunks,"(%w.+)~(%w.+)") do
            vlc.msg.dbg("b is ",b)
            temp_moments[a]=b
		    vlc.msg.dbg("here1")
          end -- second inner parser
        end 
	  moments[temp_name] = shallow_copy(temp_moments)
 	  temp_moments = {}
     end 
    end 
   i = i+1
  end 
 else 
      file = io.open(destination,"w")
	  file:write("")
	  file:close()
  end
  vlc.msg.dbg("created checkpoints_meta")
end

 function mark_position()
   checkpoints[media_name] = vlc.var.get(input,"position")
   checkpoints_meta[media_name][1] = os.date("%d/%m/%Y")
   checkpoints_meta[media_name][2] = format_time(vlc.var.get(input,"time"))
   display_checkpoint_data()
   save_checkpoints_moments(checkpoints)
  end

  function jump_to_checkpoint()
	  vlc.var.set(input,"position",checkpoints[media_name])
  end
 
 function format_time(s)
local hours = s/(60*60)
s= s%(60*60)
local minutes =s/60 
local seconds = s%60
return string.format("%02d:%02d:%02d",hours,minutes,seconds)
 end
 
 function capture_moment()
   moment_begins = vlc.var.get(input,"position")
  if vlc.playlist.status() ~= "paused" then
    vlc.playlist.pause()
  end
    caption_text_input = main_layout:add_text_input("Enter caption for the moment",1,2,3,1)
    confirm_caption_b = main_layout:add_button(" Confirm ", confirm_caption, 4,2,1,1)
 end
 
 
  function confirm_caption()
  if moments[media_name] == nil then 
    moments[media_name] = {}
  end
  if moment_begins~=nil and media_name~=nil then
  local caption_text = caption_text_input:get_text()
  main_layout:del_widget(caption_text_input)
  main_layout:del_widget(confirm_caption_b)
  capture_moment_b = main_layout:add_button(" Capture Moment ",capture_moment,1, 5, 1, 1)
  moments[media_name][caption_text] = moment_begins
  if checkpoints[media_name] == nil then
    checkpoints[media_name] = moment_begins
	checkpoints_meta[media_name][1] = os.date("%d/%m/%Y")
    checkpoints_meta[media_name][2] = format_time(vlc.var.get(input,"time"))
  end
  save_checkpoints_moments(checkpoints)
  display_moments()
  moment_begins = nil
  vlc.playlist.play()
  end
 end
 
 
 function display_moments()
 local counter = 1
 if(moments[media_name]~=nill) then
  moments_list = main_layout:add_list(1,4,4,1) -- empty moments_list widget to prevent duplicate entries
  for i,j in pairs(moments[media_name]) do
    moments_list:add_value(i .. " " .. SecondsToClock(j * media_duration),counter)
    counter = counter + 1
  end
 end
 end

-- https://gist.github.com/jesseadams/791673
 function SecondsToClock(seconds)
  local seconds = tonumber(seconds)

  if seconds <= 0 then
    return "00:00:00";
  else
    hours = string.format("%02.f", math.floor(seconds/3600));
    mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
    secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
    return hours..":"..mins..":"..secs
  end
end

 
 function jump_to_moment()
  selection = moments_list:get_selection()
     if (not selection) then return 1 end
     local sel = nil
     for idx, selectedItem in pairs(selection) do
         sel = selectedItem
         break
     end
    vlc.var.set(input,"position",moments[media_name][sel])
 end
 
  function remove_moment()
   selection = moments_list:get_selection()
     if (not selection) then return 1 end
     local sel = nil
     for idx, selectedItem in pairs(selection) do
         sel = selectedItem
         break
     end
     moments[media_name][sel] = nil
     save_checkpoints_moments(checkpoints)
     display_moments()

  end
 
 

 
 
