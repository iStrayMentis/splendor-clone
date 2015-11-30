:- include(splendor_db).
:- include(actions).

loop :-
	agent(_id),
	(_id = 0 -> 
	(	
		!,
		next_agent,
		round
	);
	(
		agents(_agents),
		nth1(_id, _agents, _agent),

		action(_agent),
		token_overload_check(_agent),
		noble_check(_agent),
		read(_),
		next_agent,
		loop
	)).

next_agent :-
	agents(_agents),
	proper_length(_agents, _nAgent),
	agent(_id),
	_idTemp is _id + 1,
	((_idTemp = _nAgent, _idNew is 0);(_idNew is _idTemp)),
	retract(agent(_)),
	assert(agent(_idNew)),
	!.

round :-
	\+condition -> end_game; loop.

end_game :-
	!,
	findall(_prestige, prestige(_, _prestige), _points),
	max_list(_points, _max),
	findall(_agent, 
		(
			prestige(_agent, _prestige),
			_prestige = _max
		),
		 _agents),
	aggregate_all(min(_nCard, _agent), 
		(
			member(_agent, _agents),
			cards(_agent, _cardsAgent),
			proper_length(_cardsAgent, _nCard)
		),
		 _winners),
	write(_winners), nl,
	halt.

condition :-
	findall(_prestige, prestige(_, _prestige), _points),
	max_list(_points, _max),
	_max < 15.

init :-
	reset_db,

	agents(_agents), proper_length(_agents, _nAgent),
	(	_nAgent = 2 -> _nToken = 4;
		_nAgent = 3 -> _nToken = 5;
		_nAgent = 4 -> _nToken = 7;
		false),
	update_tokens(board, 
		[_nToken, _nToken, _nToken, _nToken, _nToken, 5]),

	cards(deck1, _deck1),
	cards(deck2, _deck2),
	cards(deck3, _deck3),
	move_n_random(4, _deck1, [null, null, null, null], 
		_deck1New, _area1New),
	move_n_random(4, _deck2, [null, null, null, null], 
		_deck2New, _area2New),
	move_n_random(4, _deck3, [null, null, null, null], 
		_deck3New, _area3New),
	update_cards(deck1, _deck1New),
	update_cards(deck2, _deck2New),
	update_cards(deck3, _deck3New),
	update_cards(area1, _area1New),
	update_cards(area2, _area2New),
	update_cards(area3, _area3New),

	nobles(board, _nobles),
	_nNoble is _nAgent + 1,
	findall(null, between(1, _nNoble, _), _noblesOld),
	move_n_random(_nNoble, _nobles, _noblesOld, _, _noblesNew),
	update_nobles(board, _noblesNew),

	forall(
		(
			between(1, _nAgent, _i),
			nth1(_i, _agents, _agent)
		),
		(
			_agent:init_agent(_agents, _area1New, _area2New, _area3New, _noblesNew)
		)
	),
	

	assert(agent(1)),
	!.

negative_to_zero([], []) :- !.
negative_to_zero([H], [0]) :-
	H < 0, !.
negative_to_zero([H], [H]) :- !.
negative_to_zero([H|T], [0|Result]) :-
	H < 0, !,
	negative_to_zero(T, Result).
negative_to_zero([H|T], [H|Result]) :-
	negative_to_zero(T, Result).

move_n_random(_, [], To, [], To) :- !.
move_n_random(0, From, To, From, To) :- !.
move_n_random(N, From, To, Rest, Result) :-
	N > 0, M is N-1,
	random_select(Element, From, Remainder),
	select(null, To, Element, Acc), !,
	move_n_random(M, Remainder, Acc, Rest, Result),
	!.

get_affordable_cards(_agentName, _cardTuples) :-
	tokens(_agentName, _tokensAgent),
	cards(_agentName, _cardsAgent),
	calculate_agent_card_wealth(_cardsAgent, _cardWealthAgent),
	aggregate_all(
		(bag([_tier, _position])),
		(
			between(1, 3, _tier),
			between(1, 4, _position),
			atom_concat(area, _tier, _area),
			cards(_area, _cardsArea),
			nth1(_position, _cardsArea, _card),
			check_card_affordance(_card, _tokensAgent, _cardWealthAgent)
		),
		(_affordablesBoard)
	), !,

	reserves(_agentName, _reservesAgent),
	aggregate_all(
		(bag([0, _position])),
		(
			nth1(_position, _reservesAgent, _card),
			check_card_affordance(_card, _tokensAgent, _cardWealthAgent)
		),
		(_affordablesReserve)
	), !,
	append(_affordablesBoard, _affordablesReserve, _cardTuples).

check_card_affordance(_card, _tokensAgent, _cardWealthAgent):-
	append([_,_,_], _cardCostTemp, _card),
	append(_cardCostTemp, [0], _cardCost),

	maplist(plus, _cardWealthAgent, _cardEffectiveCostTemp, _cardCost),
	negative_to_zero(_cardEffectiveCostTemp, _cardEffectiveCost),
	maplist(plus, _tokensAgent, _surplus, _cardEffectiveCost),
	negative_to_zero(_surplus, _surplusActual),
	sum_list(_surplusActual, _yellowTokensNecessary),
	nth1(6, _tokensAgent, _yellowTokens),
	_yellowTokensNecessary =< _yellowTokens,
	!.

calculate_agent_card_wealth([], [0, 0, 0, 0, 0, 0]).
calculate_agent_card_wealth(_cards, _cardWealth) :-
	maplist(nth1(3), _cards, _colors),
	aggregate_all(count, member('white',	_colors), _whiteCards),
	aggregate_all(count, member('blue',		_colors), _blueCards),
	aggregate_all(count, member('green',	_colors), _greenCards),
	aggregate_all(count, member('red',		_colors), _redCards),
	aggregate_all(count, member('black',	_colors), _blackCards),
	!, _cardWealth = [_whiteCards, _blueCards, _greenCards, _redCards, _blackCards, 0].

get_affordable_nobles(_agentName, _noblesAffordable) :-
	nobles(board, _noblesBoard),
	cards(_agentName, _cardsAgent),
	calculate_agent_card_wealth(_cardsAgent, _cardWealth),
	append(_cardWealthActual, [_], _cardWealth),

	aggregate_all(
		(bag(_noble)),
		(
			member(_noble, _noblesBoard),
			(\+(_noble = null)),
			append([_], _nobleCost, _noble),
			maplist(plus, _nobleCost, _surplus, _cardWealthActual),
			min_member(_min, _surplus), _min >= 0,
			true
		),
		(_noblesAffordable)
	), !.