//==============================================================================
// Sanctified Tree Data Datum
//==============================================================================

/// Tracks per-tree ritual history and per-player soulbind registry.
/datum/sanctified_tree_data
	/// Back-reference to the owning sanctified tree.
	var/obj/structure/flora/roguetree/wise/sanctified/tree
	/// Once-per-tree ritual completion flags.
	/// Values are category ID strings: "cat1" through "cat6".
	var/list/rituals_completed = list()
	/// Per-player soulbind registry: list of ckey strings.
	var/list/soulbound_players = list()

/datum/sanctified_tree_data/New(obj/structure/flora/roguetree/wise/sanctified/owner)
	..()
	tree = owner

//==============================================================================
// Sanctified Tree
//==============================================================================
/obj/structure/flora/roguetree/wise/sanctified
	name = "sanctified tree"
	desc = "A great tree consecrated by the Treefather. Its bark glows with faint light, and the air around it thrums with primal holiness. A nexus of druidic power."
	/// Base max_integrity before nearby-tree bonus.
	max_integrity = 400
	/// Disable wise-tree autonomous retaliation. The sanctified tree
	/// cooperates with its druid warden rather than lashing out autonomously.
	activated = FALSE

	/// Datum holding ritual completion flags and the soulbind registry.
	var/datum/sanctified_tree_data/tree_data
	/// Current max_integrity bonus from nearby living trees.
	var/integrity_bonus = 0
	/// SSprocessing dt accumulator — recalculates bonus every 60 seconds.
	var/bonus_check_elapsed = 0

/obj/structure/flora/roguetree/wise/sanctified/Initialize(mapload)
	. = ..()
	tree_data = new /datum/sanctified_tree_data(src)
	set_light(3, 3, 3, l_color = "#FFD700")
	START_PROCESSING(SSprocessing, src)
	recalculate_integrity_bonus()

/obj/structure/flora/roguetree/wise/sanctified/Destroy()
	STOP_PROCESSING(SSprocessing, src)
	if(tree_data)
		qdel(tree_data)
		tree_data = null
	return ..()

/obj/structure/flora/roguetree/wise/sanctified/process(dt)
	bonus_check_elapsed += dt
	if(bonus_check_elapsed >= 60 SECONDS)
		bonus_check_elapsed = 0
		recalculate_integrity_bonus()

//==============================================================================
// Integrity Bonus
//==============================================================================

/// Recounts living trees within 10 tiles and updates max_integrity.
/// Qualifying trees: /obj/structure/flora/newtree (not burnt) and
/// /obj/structure/flora/roguetree (not wise, burnt, or stump subtypes).
/// Each tree contributes +10 integrity, capped at +200 (20 trees).
/obj/structure/flora/roguetree/wise/sanctified/proc/recalculate_integrity_bonus()
	var/tree_count = 0
	for(var/obj/structure/flora/newtree/T in range(10, src))
		if(!T.burnt)
			tree_count++
	for(var/obj/structure/flora/roguetree/T in range(10, src))
		if(istype(T, /obj/structure/flora/roguetree/wise))
			continue  // exclude wise and sanctified subtypes
		if(istype(T, /obj/structure/flora/roguetree/burnt))
			continue
		if(istype(T, /obj/structure/flora/roguetree/stump))
			continue
		tree_count++
	var/new_bonus = min(tree_count * 10, 200)
	if(new_bonus == integrity_bonus)
		return
	integrity_bonus = new_bonus
	max_integrity = 400 + integrity_bonus
	obj_integrity = min(obj_integrity, max_integrity)

/obj/structure/flora/roguetree/wise/sanctified/proc/open_ritual_menu(mob/living/user)
	to_chat(user, span_warning("The sanctified tree pulses with sacred potential — but the ritual framework has not yet been woven into it."))

/obj/structure/flora/roguetree/wise/sanctified/proc/on_soulbind(mob/living/user)
	to_chat(user, span_warning("Soulbinding has not yet been implemented for this tree."))

//==============================================================================
// Examine / Interaction
//==============================================================================
/obj/structure/flora/roguetree/wise/sanctified/examine(mob/user)
	. = ..()
	var/tree_count = 0
	for(var/obj/structure/flora/newtree/T in range(5, src))
		if(!T.burnt)
			tree_count++
	for(var/obj/structure/flora/roguetree/T in range(5, src))
		if(istype(T, /obj/structure/flora/roguetree/wise) || istype(T, /obj/structure/flora/roguetree/burnt) || istype(T, /obj/structure/flora/roguetree/stump))
			continue
		tree_count++
	. += span_info("[src] draws strength from [tree_count] nearby living tree\s, granting [integrity_bonus] bonus integrity.")
	. += span_info("Integrity: [round(obj_integrity)]/[max_integrity]")
	if(!istype(user, /mob/living/carbon/human))
		return
	var/mob/living/carbon/human/H = user
	if(H.patron?.type == /datum/patron/divine/dendor)
		. += span_notice("Hold a Dendor amulet against this tree to connect with the Treefather's power.")

/obj/structure/flora/roguetree/wise/sanctified/attackby(obj/item/I, mob/living/user, params)
	// Dendor amulet: entry point for ritual menu.
	if(istype(I, /obj/item/clothing/neck/roguetown/psicross/dendor))
		if(!istype(user, /mob/living/carbon/human))
			return
		var/mob/living/carbon/human/H = user
		if(H.patron?.type != /datum/patron/divine/dendor)
			to_chat(user, span_warning("Only a follower of Dendor may commune with this sacred tree."))
			return
		open_ritual_menu(user)
		return
	return ..()

/obj/structure/flora/roguetree/wise/sanctified/obj_destruction(damage_flag)
	set_light(0)
	visible_message(span_warning("The sanctified tree's golden light dies as it falls — the Treefather's blessing is broken!"))
	return ..()
