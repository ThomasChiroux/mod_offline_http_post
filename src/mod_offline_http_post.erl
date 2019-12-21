%% name of module must match file name
%% Update: info@ph-f.nl
-module(mod_offline_http_post).
-author("dev@codepond.org").

-behaviour(gen_mod).

-export([start/2, stop/1, create_message/1, create_message/3]).

-export([mod_opt_type/1, mod_options/1, depends/2]).

-include("xmpp.hrl").
-include("logger.hrl").

start(_Host, _Opt) ->
  ?INFO_MSG("mod_offline_http_post loading", []),
  inets:start(),
  ?INFO_MSG("HTTP client started", []),
  ejabberd_hooks:add(offline_message_hook, _Host, ?MODULE, create_message, 1).

stop (_Host) ->
  ?INFO_MSG("stopping mod_offline_http_post", []),
  ejabberd_hooks:delete(offline_message_hook, _Host, ?MODULE, create_message, 1).

depends(_Host, _Opts) ->
    [].

mod_opt_type(post_url) ->
    econf:string();
mod_opt_type(auth_token) ->
    econf:string();
mod_opt_type(confidential) ->
    econf:bool().

mod_options(Host) ->
    [{post_url, []},
     {auth_token, []},
     {confidential, []}].


create_message({Action, Packet} = Acc) when (Packet#message.type == chat) and (Packet#message.body /= []) ->
	[{text, _, Body}] = Packet#message.body,
	post_offline_message(Packet#message.from, Packet#message.to, Body, Packet#message.id),
  Acc;

create_message(Acc) ->
  Acc.

create_message(_From, _To, Packet) when (Packet#message.type == chat) and (Packet#message.body /= []) ->
  Body = fxml:get_path_s(Packet, [{elem, list_to_binary("body")}, cdata]),
  MessageId = fxml:get_tag_attr_s(list_to_binary("id"), Packet),
  post_offline_message(_From, _To, Body, MessageId),
  ok.

post_offline_message(From, To, Body, MessageId) ->
  ?INFO_MSG("Posting From ~p To ~p Body ~p ID ~p~n",[From, To, Body, MessageId]),
  Vhost = To#jid.lserver,
  ToUser = To#jid.luser,
  FromUser = From#jid.luser,
  Token = gen_mod:get_module_opt(Vhost, ?MODULE, auth_token),
  PostUrl = gen_mod:get_module_opt(Vhost, ?MODULE, post_url),
  ?INFO_MSG("Posting To ~p with token ~p ~n",[Token, PostUrl]),
  %%Token = gen_mod:get_module_opt(Vhost, ?MODULE, auth_token, fun(S) -> iolist_to_binary(S) end, list_to_binary("")),
  %%PostUrl = gen_mod:get_module_opt(Vhost, ?MODULE, post_url, fun(S) -> iolist_to_binary(S) end, list_to_binary("")),
  case gen_mod:get_module_opt(Vhost, ?MODULE, confidential) of
    true -> Data = string:join(["to=", binary_to_list(ToUser), "&from=", binary_to_list(FromUser), "&vhost=", binary_to_list(Vhost), "&messageId=", binary_to_list(MessageId)], "");
    false -> Data = string:join(["to=", binary_to_list(ToUser), "&from=", binary_to_list(FromUser), "&vhost=", binary_to_list(Vhost), "&body=", binary_to_list(Body), "&messageId=", binary_to_list(MessageId)], "")
  end,
  Request = {PostUrl, [{"Authorization", Token}], "application/x-www-form-urlencoded", Data},
  httpc:request(post, Request,[],[]),
  ?INFO_MSG("post request sent", []).
