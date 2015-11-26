:- use_module(library(pce)).


:- dynamic tokens/2.
:- dynamic cards/2.
:- dynamic nobles/2.
:- dynamic reserves/2.

:- dynamic currentAgent/1.

:- include(deck).
:- include(gui).

agents([agent1, agent2, agent3, agent4]). % Read from file

start() :-
	initialization(),
	assert(currentAgent(1)),
	run().

% add logging
run() :- % WORK WITH AGENT NAMES!
	game_did_not_end(),
	agents(_agents),
	currentAgent(_agent),
	nth1(_agent, _agents, _agentName),
	ask_action(_agentName, _actionType, _actionParameters), % pas geçme opsiyonu
	apply_action(_agentName, _actionType, _actionParameters),
	% check token over draw
	% check nobles
	next_agent(),
	run().

initialization() :-
	agents(_agents), proper_length(_agents, _nAgent),
	(	_nAgent = 2 -> _nToken = 4;
		_nAgent = 3 -> _nToken = 5;
		_nAgent = 4 -> _nToken = 7;
		false),
	_nNoble is _nAgent + 1,

	create_board(_agents),
	
	update_tokens([_nToken, _nToken, _nToken, _nToken, _nToken, 5]),

	cards(deck1, _deck1),
	cards(deck2, _deck2),
	cards(deck3, _deck3),
	nobles(board, _nobles),

	list_n_null(4, _null4),
	list_n_null(_nNoble, _nullNobles),

	draw_n_cards(4, 1, _deck1, _null4, _deck1New, _area1), !,
	draw_n_cards(4, 2, _deck2, _null4, _deck2New, _area2), !,
	draw_n_cards(4, 3, _deck3, _null4, _deck3New, _area3), !,
	draw_n_cards(_nNoble, 0, _nobles, _nullNobles, _, _noblesNew), !,

	% Reset DB with retractall???
	(retract(cards(deck1, _)); true),
	(retract(cards(deck2, _)); true),
	(retract(cards(deck3, _)); true),
	(retract(cards(area1, _)); true),
	(retract(cards(area2, _)); true),
	(retract(cards(area3, _)); true),
	(retract(nobles(board, _)); true),
	(retract(tokens(board, _)); true),

	assert(cards(deck1, _deck1New)), !,
	assert(cards(deck2, _deck2New)), !,
	assert(cards(deck3, _deck3New)), !,
	assert(cards(area1, _area1)), !,
	assert(cards(area2, _area2)), !,
	assert(cards(area3, _area3)), !,
	assert(nobles(board, _noblesNew)), !,
	assert(tokens(board, [_nToken, _nToken, _nToken, _nToken, _nToken, 5])), !,
	forall(between(1, _nAgent, _n),
		(
			atom_concat(agent, _n, _agent),
			assert(tokens(_agent, [0, 0, 0, 0, 0, 0])), !,
			assert(cards(_agent, [])), !,
			assert(reserves(_agent, [])), !,
			update_scoreboard_table(_n, [0, 0, 0, 0, 0, 0],
				[0, 0, 0, 0, 0, 0], 0),

			% nth1(PlayerNo, PlayerModules, PlayerModule)
			% atom_concat('players/', PlayerModule, PlayerModuleFile)
			% use_module(PlayerModuleFile),
			% PlayerModule:initialize(Player, PlayerCount)
			true % remove this line
		)
	),


	true. % remove this line

draw_n_cards(_, _, [], To, [], To) :- !.
draw_n_cards(0, _, From, To, From, To) :- !.
draw_n_cards(N, Tier, From, To, Rest, Result) :-
	N > 0, M is N-1,
	random_select(Card, From, Remainder),
	proper_length(Remainder, CardsLeft),
	nth1(1, Card, CardId),
	nth1(Index, To, null),
	select(null, To, Card, Acc),
	update_card(CardId, Tier, Index),
	write_card_left(Tier, CardsLeft),
	draw_n_cards(M, Tier, Remainder, Acc, Rest, Result),
	!.

list_n_null(0, []) :- !.
list_n_null(1, [null]) :- !.
list_n_null(N, [null|List]) :-
	N > 0, M is N-1,
	list_n_null(M, List).

list_n_duplicate(0, _, []) :- !.
list_n_duplicate(1, X, [X]) :- !.
list_n_duplicate(N, X, [X|List]) :-
	N > 0, M is N-1,
	list_n_duplicate(M, X, List).


take_tokens(_agent, _tokens) :- % #token > 10 ise return tokens until #token = 10
	proper_length(_tokens, 5), 
	min_member(_min, _tokens), _min = 0,
	
	nth1(1, _tokens, _white),
	nth1(2, _tokens, _blue),
	nth1(3, _tokens, _green),
	nth1(4, _tokens, _red),
	nth1(5, _tokens, _black),

	tokens(board, _tokensBoard),
	nth1(1, _tokensBoard, _tokensBoardWhite),
	nth1(2, _tokensBoard, _tokensBoardBlue),
	nth1(3, _tokensBoard, _tokensBoardGreen),
	nth1(4, _tokensBoard, _tokensBoardRed),
	nth1(5, _tokensBoard, _tokensBoardBlack),
	nth1(6, _tokensBoard, _tokensBoardYellow),

	_whiteLeft	is _tokensBoardWhite	- _white,
	_blueLeft	is _tokensBoardBlue		- _blue,
	_greenLeft	is _tokensBoardGreen	- _green,
	_redLeft	is _tokensBoardRed		- _red,
	_blackLeft	is _tokensBoardBlack	- _black,

	_whiteLeft	>= 0,
	_blueLeft	>= 0,
	_greenLeft	>= 0,
	_redLeft	>= 0,
	_blackLeft	>= 0,
	!,
	(_white > 0 -> _betaWhite	= 1;	_betaWhite	= 0),
	(_blue  > 0 -> _betaBlue	= 1;	_betaBlue	= 0),
	(_green > 0 -> _betaGreen	= 1;	_betaGreen	= 0),
	(_red 	> 0 -> _betaRed		= 1;	_betaRed	= 0),
	(_black > 0 -> _betaBlack	= 1;	_betaBlack	= 0),

	sum_list(_tokens, _tokensSum),
	_betaSum is (_betaWhite + _betaBlue + _betaGreen + _betaRed + _betaBlack),
	!,
	(
		(_betaSum = 1, _tokensSum = 2) -> 
			(
				!,
				(_betaWhite	= 0; _whiteLeft	>= 2),
				(_betaBlue	= 0; _blueLeft 	>= 2),
				(_betaGreen	= 0; _greenLeft >= 2),
				(_betaRed	= 0; _redLeft	>= 2),
				(_betaBlack = 0; _blackLeft >= 2),
				!
			);
			(
				(_betaSum = 3, _tokensSum = 3) -> 
					!;
					(
						(_tokensSum = 2; _tokensSum = 1) -> 
							(
								!,
								(_white = 0 -> _whiteLeft	= 0; true),
								(_blue 	= 0 -> _blueLeft	= 0; true),
								(_green = 0 -> _greenLeft	= 0; true),
								(_red 	= 0 -> _redLeft		= 0; true),
								(_black = 0 -> _blackLeft	= 0; true),
								!
							);
							(
								!, false
							)
					)
			)
	),
	!,
	_tokensBoardNew = [_whiteLeft, _blueLeft, _greenLeft, _redLeft, _blackLeft, _tokensBoardYellow],
	tokens(_agent, _tokensAgent),
	last(_tokensAgent, _yellowAgent),
	append(_tokens, [_yellowAgent], _tokensWithYellow),
	maplist(plus, _tokensAgent, _tokensWithYellow, _tokensAgentNew),
	!,
	retract(tokens(board, _)),
	assert(tokens(board, _tokensBoardNew)),
	retract(tokens(_agent, _)),
	assert(tokens(_agent, _tokensAgentNew)),
	!,
	% GUI
	update_tokens(_tokensBoardNew),
	update_scores_agent(_agent),
	true.

update_scores_agent(_agentName) :-
	agents(_agents),
	nth1(_agentId, _agents, _agentName),
	tokens(_agentName, _tokens),
	cards(_agentName, _cards),
	calculate_agent_card_wealth(_cards, _cardWealth),
	calculate_score(_agentName, _score),
	update_scoreboard_table(_agentId, _tokens, _cardWealth, _score).

calculate_score(_agentName, _score) :-
	cards(_agentName, _cards),
	maplist(nth1(2), _cards, _scores),
	% ADD NOBLES SCORE
	sum_list(_scores, _score).

calculate_agent_card_wealth(_cards, _cardWealth) :-
	maplist(nth1(3), _cards, _colors),
	aggregate_all(count, member('white',	_colors), _whiteCards),
	aggregate_all(count, member('blue',		_colors), _blueCards),
	aggregate_all(count, member('green',	_colors), _greenCards),
	aggregate_all(count, member('red',		_colors), _redCards),
	aggregate_all(count, member('black',	_colors), _blackCards),
	!, _cardWealth = [_whiteCards, _blueCards, _greenCards, _redCards, _blackCards, 0].

card_effective_cost(_agentName, _card, _cardEffectiveCost) :-
	append([_,_,_], _cardCostTemp, _card),
	append(_cardCostTemp, [0], _cardCost),

	cards(_agentName, _cardsAgent),
	calculate_agent_card_wealth(_cardsAgent, _cardWealthAgent),

	maplist(plus, _cardCost, _cardEffectiveCostTemp, _cardWealthAgent),

	negative_to_zero(_cardEffectiveCostTemp, _cardEffectiveCost).

get_affordable_cards(_agentName, _cardTuples) :-
	tokens(_agentName, _tokensAgent),
	cards(_agentName, _cardsAgent),
	calculate_agent_card_wealth(_cardsAgent, _cardWealthAgent),
	aggregate_all(
		(bag([_tier, _position])),
		(count),
		(
			between(1, 3, _tier),
			between(1, 4, _position),
			atom_concat(area, _tier, _area),
			cards(_area, _cardsArea),
			nth1(_position, _cardsArea, _card),
			append([_,_,_], _cardCostTemp, _card),
			append(_cardCostTemp, [0], _cardCost),
			maplist(plus, _cardWealthAgent, _cardEffectiveCostTemp, _cardCost),
			negative_to_zero(_cardEffectiveCostTemp, _cardEffectiveCost),
			maplist(plus, _tokensAgent, _surplus, _cardEffectiveCost),
			aggregate_all(sum(X), (nth1(I, _surplus, X), I < 6), _yellowTokensNecessary),
			nth1(6, _surplus, _yellowTokens),
			0 >= _yellowTokensNecessary + _yellowTokens,
			true
		),
		(_cardTuples)
	),
	!.

mark_affordable_cards( _agentName) :-
	aggregate_all(
		(count),
		(
			between(1, 3, _tier),
			between(1, 4, _position),
			unmark_card([_tier, _position]),
			true
		),
		(_)
	),
	!,
	get_affordable_cards(_agentName, _cardTuples),
	aggregate_all(
		(count),
		(
			member(_cardTuple, _cardTuples),
			mark_card(_cardTuple)
		),
		(_)
	),
	!.

purchase_card(_agentName, [_tier, _position, _tokens]) :-
	tokens(_agentName, _tokensAgent),
	maplist(plus, _tokens, _tokensDifference, _tokensAgent),
	maplist(between(0, infinite), _tokensDifference),

	between(1, 3, _tier),
	between(1, 4, _position),

	atom_concat(area, _tier, _area),
	atom_concat(deck, _tier, _deck),
	
	cards(_area, _cardsArea),
	cards(_deck, _cardsDeck),
	
	nth1(_position, _cardsArea, _card),
	card_effective_cost(_agentName, _card, _cardEffectiveCost),
	
	maplist(plus, _cardEffectiveCost, _surplus, _tokens),
	aggregate_all(sum(X), (nth1(I, _surplus, X), I < 6), _yellowTokensNecessary),
	nth1(6, _surplus, _yellowTokens),
	0 is _yellowTokens + _yellowTokensNecessary,

	!, % AFFORDANCE CHECK SUCCESSFUL

	tokens(board, _tokensBoard),
	maplist(plus, _tokensBoard, _tokens, _tokensBoardNew),
	cards(_agentName, _cardsAgent),
	append(_cardsAgent, [_card], _cardsAgentNew),
	select(_card, _cardsArea, null, _cardsAreaTemp),
	draw_n_cards(1, _tier, _cardsDeck, _cardsAreaTemp, _cardsDeckNew, _cardsAreaNew),

	retract(tokens(board, _)),
	assert(tokens(board, _tokensBoardNew)),

	retract(tokens(_agentName, _)),
	assert(tokens(_agentName, _tokensDifference)),
	
	retract(cards(_agentName, _)),
	assert(cards(_agentName, _cardsAgentNew)),

	retract(cards(_area, _)),
	assert(cards(_area, _cardsAreaNew)),
	
	retract(cards(_deck, _)),
	assert(cards(_deck, _cardsDeckNew)),

	update_tokens(_tokensBoardNew),
	update_scores_agent(_agentName).

reserve_card(_agentName, [_tier, _position]) :- 
	reserves(_agentName, _reservesAgent),
	proper_length(_reservesAgent, _reserveCount),
	(_reserveCount = 3 -> false; true),

	between(1, 3, _tier),
	atom_concat(deck, _tier, _deck),
	cards(_deck, _cardsDeck),
	
	(_position = 0 ->
		(	append(_reservesAgent, [null], _reservesAgentTemp),
			draw_n_cards(1, _tier, _cardsDeck, _reservesAgentTemp, _cardsDeckNew, _reservesAgentNew),
			retract(reserves(_agentName, _)),
			assert(reserves(_agentName, _reservesAgentNew)));
		(	between(1, 4, _position),
			atom_concat(area, _tier, _area), 	
			cards(_area, _cardsArea),
			nth1(_position, _cardsArea, _card),
			select(_card, _cardsArea, null, _cardsAreaTemp),
			draw_n_cards(1, _tier, _cardsDeck, _cardsAreaTemp, _cardsDeckNew, _cardsAreaNew),
			retract(cards(_area, _)),
			assert(cards(_area, _cardsAreaNew)))
	),
	retract(cards(_deck, _)),
	assert(cards(_deck, _cardsDeckNew)),

	tokens(board, _tokensBoard),
	nth1(6, _tokensBoard, _tokensBoardYellow),
	(_tokensBoardYellow > 0 ->
		(	_tokensBoardYellowNew is _tokensBoardYellow - 1,
			append(_tokensBoardTemp, [_], _tokensBoard),
			append(_tokensBoardTemp, [_tokensBoardYellowNew], _tokensBoardNew),
			tokens(_agentName, _tokensAgent),
			nth1(6, _tokensAgent, _tokensAgentYellow),
			_tokensAgentYellowNew is _tokensAgentYellow + 1,
			append(_tokensAgentTemp, [_], _tokensAgent),
			append(_tokensAgentTemp, [_tokensAgentYellowNew], _tokensAgentNew),
			retract(tokens(board, _)),
			assert(tokens(board, _tokensBoardNew)),
			retract(tokens(_agentName, _)),
			assert(tokens(_agentName, _tokensAgentNew)));
		(	true)
	),

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


game_did_not_end() :- !.

next_agent() :- !.


ask_action(_agentName, _actionType, _actionParameters) :-
	print_board(),
	write('I am agent: '), write(_agentName), nl,
  	write('Action?'), nl,
	read(_actionType),
	write('Parameters?'), nl,
	read(_actionParameters).


apply_action(_agentName, _actionType, _actionParameters) :-
	between(1, 3, _actionType),
	(	_actionType = 1 -> take_tokens(_agentName, _actionParameters);
		_actionType = 2 -> purchase_card(_agentName, _actionParameters);
		_actionType = 3 -> reserve_card(_agentName, _actionParameters);
		false).


print_board() :-
	tokens(board, _tokensBoard),
	% foreach player get tokens, cards, nobles, reserves
	cards(area1, _area1),
	cards(area2, _area2),
	cards(area3, _area3),
	nobles(board, _noblesBoard),

	write('Tokens available: '), write(_tokensBoard), nl,
	write('Nobles: '), write(_noblesBoard), nl,
	write('Cards tier 3: '), write(_area3), nl,
	write('Cards tier 2: '), write(_area2), nl,
	write('Cards tier 1: '), write(_area1), nl,
	true.