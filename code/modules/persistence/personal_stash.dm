/obj/structure/personal_stash
	name = "ColMarTech Personal Stash Access Point"
	desc = "A jury-rigged ColMarTech vendor which pulls from the mostly-empty bowels of the ship. It can be used to save various objects for use between operations."
	icon = 'icons/obj/structures/machinery/vending.dmi'
	icon_state = "prep"
	density = TRUE

	light_range = 4
	light_power = 2
	light_color = "#ebf7fe"  //white blue

	var/json_file
	var/unique_id
	var/list/stored_items = list()

// ↓ only the crap we care about saving. The code should be versitile enough to be able to just add things on
	var/list/allowed_vars = list(
	"contents", "name", "desc", "accessories", "ammo", "attachments", "current_mag", "pockets", "in_chamber", "current_rounds", "default_ammo"
	)

// /obj/structure/personal_stash/Initialize(mapload, ...)
// 	. = ..()

/obj/structure/personal_stash/attack_hand(mob/user)
// 	tgui_interact(user)
	load_stash(user)





// /obj/structure/personal_stash/tgui_interact(mob/user, datum/tgui/ui)
// 	ui = SStgui.try_update_ui(user, src, ui)
// 	if(!ui)
// 		ui = new(user, src, "ItemStash", "Personal Stash")
// 		ui.open()

// /obj/structure/personal_stash/ui_data(mob/user)
// 	var/list/data = list()

// 	data["contents"] = contents
// 	return data

// /obj/structure/personal_stash/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
// 	. = ..()
// 	if(.)
// 		return

// 	var/mob/living/carbon/human/user = ui.user

// 	switch(action)
// 		if("login")
// 			load_stash(user)
// 		if("logout")
// 			unload_stash()
// 		if("item_click")

/obj/structure/personal_stash/proc/load_stash(mob/user)
	unique_id = user.ckey
	// var/savefile/stash = new("data/player_saves/[copytext(unique_id,1,2)]/[unique_id]/stash.sav")
	stored_items.Cut()

	json_file = file("data/player_saves/[copytext(unique_id,1,2)]/[unique_id]/stash.json")


	//message_admins("bro")
	if(!fexists(json_file))
		return

	json_file = file2text(json_file)
	var/list/json = json_decode(json_file)

	for(var/item_index in 1 to json.len)
		//message_admins("[json.len] [item_index]")

		var/list/loaded_item = json[json[item_index]]

		var/I = recreate_item(loaded_item, loc)
		if(istype(I, /obj))
			var/obj/Item = I
			Item.update_icon()

/obj/structure/personal_stash/proc/recreate_item(list/item_template, atom/location)
	var/datum/loaded_item = text2path(item_template[item_template[1]])
	loaded_item = new loaded_item(location)

	var/list/vars2load = list()
	vars2load = (allowed_vars & loaded_item.vars)

	for(var/key in vars2load)
		if(islist(item_template[key]))
			loaded_item.vars[key] = list() //wipes the list on the freshly initialized object

			var/list/list_var_template = item_template[key]
			if(!list_var_template.len)
				continue

			for(var/index in 1 to list_var_template.len)
				message_admins("[list_var_template[index]] naw [list_var_template[list_var_template[index]]]")
				var/reconstructed_item	= list_var_template[list_var_template[index]]
				if(key == "contents") //we don't care about exactly recreating items anywhere but in the contents (attachments are in contents AND their own var)
					recreate_item(reconstructed_item, loaded_item)
				else if(istext(list_var_template[index]) && text2path(list_var_template[list_var_template[index]]))
					message_admins("locating [list_var_template[list_var_template[index]]]")
					var/L = locate(text2path(list_var_template[list_var_template[index]])) in loaded_item
					message_admins("found [L]")
					message_admins("saving to [loaded_item.vars[key][list_var_template[index]]]")
					loaded_item.vars[key][list_var_template[index]] = L
				else
					loaded_item.vars[key] = list_var_template[list_var_template[index]]

		else

			if(item_template[key])

				if(text2path(item_template[key]))

					var/L = locate(text2path(item_template[key])) in loaded_item

					loaded_item.vars[key] = L

				else
					loaded_item.vars[key] = item_template[key]

		update_icon(loaded_item)

		return loaded_item


/obj/structure/personal_stash/attackby(obj/item/W, mob/user)
	stored_items += W
	user.drop_held_item(W)
	W.forceMove(src)
	unique_id = user.ckey
	unload_stash()


/obj/structure/personal_stash/proc/unload_stash()
	if(!unique_id)
		return

	json_file = file("data/player_saves/[copytext(unique_id,1,2)]/[unique_id]/stash.json")

	unique_id = null

	var/list/data2save = list()

	for(var/i in 1 to stored_items.len)
		data2save["[stored_items[i]]_[i]"] = get_vars(stored_items[i])
	fdel(json_file)
	WRITE_FILE(json_file, json_encode(data2save))




/obj/structure/personal_stash/proc/get_vars(obj/item/item, iteration)
	if(!item.vars)
		return

	var/list/item_entry = list()
	item_entry["item"] = item.type

	var/atom/control = DuplicateObject(item, FALSE, TRUE) //makes a 'control' item with default vars to compare to, since initial() is too strict

	var/list/vars2save = list()
	vars2save = (allowed_vars & item.vars)

	for(var/V in vars2save)
		if(islist(item.vars[V]))

			if(!iteration)
				iteration++ //so we don't iterate infinitely for weird edge cases

			var/list/list_var = item.vars[V]

			var/list/contents_list = list()
			for(var/index in 1 to list_var.len)
				if(iteration <= 8)
					if(istype(list_var[index], /datum))
						contents_list["[V]_[index]"] = get_vars(list_var[index], iteration)
					else if(istext(list_var[index]) && istype(list_var[list_var[index]], /datum))
						var/datum/T = list_var[list_var[index]]
						contents_list["[list_var[index]]"] = T.type

			item_entry["[V]"] = contents_list

		else
			if(item.vars[V] != control.vars[V])
				if(istype(item.vars[V], /datum))
					var/datum/T = item.vars[V]
					item_entry["[V]"] = T.type
				else
					item_entry["[V]"] = item.vars[V]

	qdel(control)
	return item_entry




	// for(var/v in item.vars)
	// 	if(istype(item.vars[v], /obj/item/storage/internal))
	// 		message_admins("[item] has internal storage as [v]")

	// 		item_entry["[v]"] = item.vars[v]


	// 	if(islist(item.vars[v]))
	// 		if(item.vars[v] ~! control.vars[v])
	// 			message_admins("LIST [v] is changd from [control.vars[v]] to [item.vars[v]]")

	// 			item_entry["[v]"] = item.vars[v]

	// 	else
	// 		if(item.vars[v] != control.vars[v])
	// 			message_admins("[v] is changd from [control.vars[v]] to [item.vars[v]]")

	// 			item_entry["[v]"] = item.vars[v]


	// qdel(control)

	// if(item.contents.len && iteration <= 8)
	// 	message_admins("iteration [iteration++]")

	// 	if(!iteration)
	// 		iteration++ //so we don't iterate infinitely for weird edge cases

	// 	for(var/i in 1 to item.contents.len)

	// 		item_entry["contents[i]"] = item.contents[i].type	//saves variable name

	// 		get_vars(item.contents[i], iteration)

	// return item_entry

//obj/item/storage/internal





// /obj/machinery/smartfridge/black_box/proc/WriteMemory()
// 	var/json_file = file("data/npc_saves/Blackbox.json")
// 	stored_items = list()
// 	for(var/obj/O in (contents-component_parts))
// 		stored_items += O.type
// 	var/list/file_data = list()
// 	file_data["data"] = stored_items
// 	fdel(json_file)
// 	WRITE_FILE(json_file, json_encode(file_data))

// /obj/machinery/smartfridge/black_box/proc/ReadMemory()
// 	if(fexists("data/npc_saves/Blackbox.sav")) //legacy compatability to convert old format to new
// 		var/savefile/S = new /savefile("data/npc_saves/Blackbox.sav")
// 		S["stored_items"] >> stored_items
// 		fdel("data/npc_saves/Blackbox.sav")
// 	else
// 		var/json_file = file("data/npc_saves/Blackbox.json")
// 		if(!fexists(json_file))
// 			return
// 		var/list/json = json_decode(rustg_file_read(json_file))
// 		stored_items = json["data"]
// 	if(isnull(stored_items))
// 		stored_items = list()
// 	for(var/item in stored_items)
// 		create_item(item)
