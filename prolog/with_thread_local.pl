/* Part of LogicMOO Base Logicmoo Debug Tools
% ===================================================================
% File 'with_thread_local.pl'
% Purpose: An Implementation in SWI-Prolog of certain debugging tools
% Maintainer: Douglas Miles
% Contact: $Author: dmiles $@users.sourceforge.net ;
% Version: 'with_thread_local.pl' 1.0.0
% Revision: $Revision: 1.1 $
% Revised At:  $Date: 2002/07/11 21:57:28 $
% Licience: LGPL
% ===================================================================
*/
% File: /opt/PrologMUD/pack/logicmoo_base/prolog/logicmoo/util/logicmoo_util_with_assertions.pl
:- module(with_thread_local,
          [ locally/2,
            locally_each/2,
            locally_hide/2,
            locally_hide_each/2
          ]).

:- meta_predicate
        locally((:),(:)),
        locally_each((:),(:)),
        locally_hide((:),(:)),        
        locally_hide_each((:),(:)),
        wtl(+,*,0,3),
        wtl_how(3,0,0,0,0).        
        
        
:- module_transparent
        check_thread_local_1m/1,
        to_thread_local_1m/3,
        key_asserta/2,
        key_erase/1,
        module_effect/3.

:- set_module(class(library)).


:- use_module(library(each_call_cleanup)).


%% locally_hide_each( :Fact, :Call) is nondet.
%
%  Temporally Disable Fact with `Fact :- !,fail.`
%
%  use locally_hide_each/3 if respecting Non-determism is important 
% (slightly slower?)
 
locally_hide(Fact,Cm:Call):-
  module_effect((Fact :- !,fail),M,BareEffect) ->
    wtl(M,BareEffect,Cm:Call,Cm:setup_call_cleanup).

%% locally_hide_each( :Fact, :Call) is nondet.
%
%  Temporally Disable Fact with `Fact :- !,fail.`
%
%  But Ensure Non-determism is respected (slightly slower?)
%
%  uses each_call_cleanup/3 instead of setup_call_cleanup/3
 
locally_hide_each(Fact,Cm:Call):-
  module_effect((Fact :- !,fail),M,BareEffect) ->
    wtl(M,BareEffect,Cm:Call,Cm:each_call_cleanup).


%% locally_each( :Effect, :Call) is nondet.
%
%  Temporally have :Effect (see locally/2)
%
%  But Ensure Non-determism is respected (effect is undone between Redos)
%
%  uses each_call_cleanup/3 instead of setup_call_cleanup/3 (slightly slower?)
%
% for example,
%
%  locally_each/2 works (Does not throw)
% ===
% ?- current_prolog_flag(xref,Was), 
%     locally_each(set_prolog_flag(xref,true),
%     assertion(current_prolog_flag(xref,true));assertion(current_prolog_flag(xref,true))),
%     assertion(current_prolog_flag(xref,Was)),fail.
% ===
%
%  locally/2 does not work (it throws instead)
% ===
% ?- current_prolog_flag(xref,Was), 
%     locally(set_prolog_flag(xref,true),
%     assertion(current_prolog_flag(xref,true));assertion(current_prolog_flag(xref,true))),
%     assertion(current_prolog_flag(xref,Was)),fail.
% ===
locally_each(Effect,Cm:Call):-
   module_effect(Effect,M,BareEffect) ->
     wtl(M,BareEffect,Cm:Call,Cm:each_call_cleanup).

%% locally( :Effect, :Call) is nondet.
%
% Effect may be of type:
%
%  set_prolog_flag -
%     Temporarily change prolog flag
%
%  op/3 - 
%     change op
%
%  $gvar=Value -
%     set a global variable
%
%  Temporally (thread_local) Assert some :Effect 
%
%  use locally_each/3 if respecting Non-determism is important 
% (slightly slower?)
%
% ===
% ?- current_prolog_flag(xref,Was), 
%     locally(set_prolog_flag(xref,true),
%     assertion(current_prolog_flag(xref,true))),
%     assertion(current_prolog_flag(xref,Was)). 
% ===

locally(Effect,Cm:Call):-
   module_effect(Effect,M,BareEffect) ->
     wtl(M,BareEffect,Cm:Call,Cm:setup_call_cleanup).



wtl(_,[],Call,_):- !,Call.
wtl(M,+With,Call,How):- !,wtl(M,With,Call,How).
wtl(M,-[With|MORE],Call,How):- !,wtl(M,-With,wtl(M,-MORE,Call,How),How).
wtl(M,[With|MORE],Call,How):- !,wtl(M,With,wtl(M,MORE,Call,How),How).
wtl(M,(With,MORE,How),Call,How):- !,wtl(M,With,wtl(M,MORE,Call,How),How).
wtl(M,(With;MORE,How),Call,How):- !,wtl(M,With,Call,How);wtl(M,MORE,Call,How).
wtl(M,not(With),Call,How):- !,wtl(M,- With,Call,How).
wtl(M,-With,Call,setup_call_cleanup):- !,locally_hide(M:With,Call).
wtl(M,-With,Call,_How):- !,locally_hide_each(M:With,Call).


wtl(M,op(New,XFY,OP),Call,How):- 
  (M:current_op(PrevN,XFY,OP);PrevN=0),!,
   wtl_how(How, PrevN==New , op(New,XFY,OP), Call, op(PrevN,XFY,OP)).

wtl(_,set_prolog_flag(N,VALUE),Call,How):- 
  (current_prolog_flag(N,WAS);WAS=unknown_flag_error(set_prolog_flag(N,VALUE))),!,
   wtl_how(How, VALUE==WAS, set_prolog_flag(N,VALUE),Call,set_prolog_flag(N,WAS)).

wtl(_,$N=VALUE,Call,How):- 
  (nb_current(N,WAS) -> 
    (b_setval(N,VALUE),wtl_how(How, VALUE==WAS,b_setval(N,VALUE),Call,b_setval(N,WAS)));
    (b_setval(N,VALUE),wtl_how(How, fail, nb_setval(N,VALUE),Call,nb_delete(N)))).

% undocumented
wtl(M,before_after(Before,After,How),Call,How):- !,
     (M:Before -> call(How,true,Call,M:After); Call).

wtl(M,Assert,Call,setup_call_cleanup):- !,
   wtl_how(setup_call_cleanup,clause_true(M,Assert),M:asserta(M:Assert,Ref),Call,M:erase(Ref)).

wtl(M,Assert,Call,How):- 
   wtl_how(How,clause_true(M,Assert),key_asserta(M,Assert),Call,key_erase(M)).

clause_true(M,(H:-B)):- functor(H,F,A),functor(HH,F,A),M:nth_clause(HH,1,Ref),M:clause(HH,BB,Ref),!,(H:-B)=@=(HH:-BB).
clause_true(M, H    ):- copy_term(H,HH),M:clause(H,true),!,H=@=HH.

% wtl_how(How, Test , Pre , Call, Post)

wtl_how(setup_call_cleanup, Test , Pre , Call, Post):- !, (Test -> Call ; setup_call_cleanup(Pre , Call, Post)).
wtl_how(each_call_cleanup, _Test , Pre , Call, Post):- each_call_cleanup(Pre , Call, Post).
wtl_how(How, Test , Pre , Call, Post):-  Test -> Call ; call(How, Pre , Call, Post).


:- nb_setval('$w_tl_e',[]).

key_asserta(M,Assert):- M:asserta(M:Assert,REF),
 (nb_current('$w_tl_e',Was)->nb_setval('$w_tl_e',[REF|Was]);nb_setval('$w_tl_e',[REF])).

key_erase(M):- nb_current('$w_tl_e',[REF|Was])->nb_setval('$w_tl_e',Was)->M:erase(REF).




module_effect(+M:Call,M,+Call).
module_effect(-M:Call,M,-Call).
module_effect(_:op(N,XFY,M:OP),M,op(N,XFY,OP)).
module_effect(op(N,XFY,M:OP),M,op(N,XFY,OP)).
module_effect(M:set_prolog_flag(FM:Flag,Value),M,set_prolog_flag(FM:Flag,Value)).
module_effect(M:set_prolog_flag(Flag,Value),M,set_prolog_flag(M:Flag,Value)).
%module_effect(FM:set_prolog_flag(Flag,Value),FM,set_prolog_flag(FM:Flag,Value)).
module_effect($M:N=V,M,$N=V).

module_effect(Assert,Module,ThreadLocal):-
   module_effect_striped(Assert,Module,Stripped),
   to_thread_local_1m(Stripped,Module,ThreadLocal).

module_effect(Call,Module,UnQCall):- strip_module(Call,Module,UnQCall).


module_effect_striped(_:((M:H):-B), M,(H:-B)).
module_effect_striped(M:(H:-B), M,(H:-B)).
module_effect_striped(((M:H):-B), M,(H:-B)).
module_effect_striped(M:H,M,M:H).
module_effect_striped(Call,Module,UnQCall):- strip_module(Call,Module,UnQCall).


%% to_thread_local_1m( ?Call, ?Module, ?ThreadLocal) is det.
%
% Converted To Thread Local Head 
%
to_thread_local_1m((TL:Head :- BODY),_,(TL:Head :- BODY)):- nonvar(TL),check_thread_local_1m(TL:Head).
to_thread_local_1m((H:-B),TL,(HH:-B)):-!,to_thread_local_1m(H,TL,HH).
to_thread_local_1m(Head,baseKB,t_l:Head).
to_thread_local_1m(Head,t_l,t_l:Head).
to_thread_local_1m(Head,tlbugger,tlbugger:Head).
to_thread_local_1m(Head,TL,TL:Head):-check_thread_local_1m(TL:Head).


%% check_thread_local_1m( ?TLHead) is nondet.
%
% Check Thread Local 1m.
%
check_thread_local_1m(_):- \+ current_prolog_flag(runtime_safety,3), \+ current_prolog_flag(runtime_speed,0).
check_thread_local_1m(t_l:_):-!.
check_thread_local_1m((H:-_)):-!,check_thread_local_1m(H).
check_thread_local_1m(tlbugger:_):-!.
check_thread_local_1m(lmcache:_):-!.
check_thread_local_1m(TLHead):- predicate_property(TLHead,(thread_local)).
