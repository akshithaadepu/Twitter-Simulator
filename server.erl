-module(server).
-import(maps, []).
-export[start/0].

start() ->
    io:fwrite("\n\n Tweeter Engine \n\n"),
    table = ets:new(messages, [uniqueOrderedList, tableName, openPost]),
    clientSocketMapper = ets:new(clients, [uniqueOrderedList, tableName, openPost]),
    allClients = [],
    map = maps:new(),
    {ok, listenToSocket} = gen_tcp:listen(1204, [binary, {keepalive, true}, {reuseaddr, true}, {active, false}]),
    connectorListen(listenToSocket, table, clientSocketMapper).

connectorListen(hear, table, clientSocketMapper) ->
    {ok, socket} = gen_tcp:accept(hear),
    ok = gen_tcp:send(socket, "ETL JSON"),
    spawn(fun() -> connectorListen(hear, table, clientSocketMapper) end),
    recieverListen(socket, table, [], clientSocketMapper).

recieverListen(socket, table, Bs, clientSocketMapper) ->
    io:fwrite("Recieving.. \n\n"),
    case gen_tcp:recv(socket, 0) of
        {ok, deetstweets} ->
            
            deets = re:split(deetstweets, ","),
            typeOfCommand = binary_to_list(lists:nth(1, deets)),

            if 
                typeOfCommand == "signup" ->
                    userID = binary_to_list(lists:nth(2, deets)),
                    processID = binary_to_list(lists:nth(3, deets)),
                    tableLookup = ets:lookup(table, userID),
                    io:format("Output: ~p\n", [tableLookup]),
                    if
                        tableLookup == [] ->

                            ets:insert(table, {userID, [{"followers", []}, {"posts", []}]}),      
                            ets:insert(clientSocketMapper, {userID, socket}),                
                            listTemporary = ets:lookup(table, userID),
                            io:format("~p", [lists:nth(1, listTemporary)]),
                            ok = gen_tcp:send(socket, "User has been registered\n"),
                            io:fwrite("Good to go, UserID is unique\n");
                        true ->
                            ok = gen_tcp:send(socket, "UserID exists, signin if its you, else signup")
                            %io:fwrite("Duplicate key!\n")
                    end,
                    recieverListen(socket, table, [userID], clientSocketMapper);

                typeOfCommand == "post" ->
                    userID = binary_to_list(lists:nth(2, deets)),
                    post = binary_to_list(lists:nth(3, deets)),
                    io:format("\n ~p sent the following post: ~p", [userID, post]),
                    value = ets:lookup(table, userID),
                    io:format("tableLookup: ~p\n", [value]),
                    column3 = lists:nth(1, value),
                    column2 = element(2, column3),
                    column1 = maps:from_list(column2),
                    {ok, subscribersList} = maps:find("followers",column1),                         
                    {ok, listOfposts} = maps:find("tweets",column1),

                    newPosts = listOfposts ++ [post],
                    io:format("~p~n",[newPosts]),
                    
                    ets:insert(table, {userID, [{"followers", subscribersList}, {"tweets", newPosts}]}),

                    listOfpostsCheck = ets:lookup(table, userID),
                    io:format("\nposts after posting: ~p\n", [listOfpostsCheck]),
                  
                    sendMessage(socket, clientSocketMapper, post, subscribersList, userID),
                    ok = gen_tcp:send(socket, "Server sent post to all the subscribers\n"),
                    recieverListen(socket, table, [userID], clientSocketMapper);

                typeOfCommand == "repost" ->
                    userIDperson = binary_to_list(lists:nth(2, deets)),
                    userID = binary_to_list(lists:nth(3, deets)),
                    consideredUser = string:strip(userIDperson, right, $\n),
                    io:format("User to repost from: ~p\n", [consideredUser]),
                    post = binary_to_list(lists:nth(4, deets)),
                    outOfUsers = ets:lookup(table, consideredUser),
                    if
                        outOfUsers == [] ->
                            io:fwrite("User does not exist!\n");
                        true ->
                            outOfUsers1 = ets:lookup(table, userID),
                            column3 = lists:nth(1, outOfUsers1),
                            column2 = element(2, column3),
                            column1 = maps:from_list(column2),
                            column_3 = lists:nth(1, outOfUsers),
                            column_2 = element(2, column_3),
                            column_1 = maps:from_list(column_2),
                            {ok, subscribersList} = maps:find("followers",column1),
                            {ok, listOfposts} = maps:find("tweets",column_1),
                            io:format("Tweet to be re-posted: ~p\n", [post]),
                            checkPostsInList = lists:member(post, listOfposts),
                            if
                                checkPostsInList == true ->
                                    newRepost = string:concat(string:concat(string:concat("re:",consideredUser),"->"),post),
                                    sendMessage(socket, clientSocketMapper, newRepost, subscribersList, userID);
                                true ->
                                    io:fwrite("Please try again!\n")
                            end     
                    end,
                    ok = gen_tcp:send(socket, "Server processed repost\n"),
                    recieverListen(socket, table, [userID], clientSocketMapper);

                typeOfCommand == "follow" ->
                    userID = binary_to_list(lists:nth(2, deets)),
                    userIDToFollow = binary_to_list(lists:nth(3, deets)),
                    consideredUser = string:strip(userIDToFollow, right, $\n),
                    checkForTheConsideredUser = ets:lookup(table, consideredUser),
                    if
                        checkForTheConsideredUser == [] ->
                            io:fwrite("Please try again. \n");
                        true ->
                            value = ets:lookup(table, consideredUser),
                            column3 = lists:nth(1, value),
                            column2 = element(2, column3),
                            column1 = maps:from_list(column2),                            
                            {ok, subscribersList} = maps:find("followers",column1),
                            {ok, listOfposts} = maps:find("tweets",column1),

                            appendFollowers = subscribersList ++ [userID],
                            ets:insert(table, {consideredUser, [{"followers", appendFollowers}, {"tweets", listOfposts}]}),
                            checkOutForConsideredUser2 = ets:lookup(table, consideredUser),
                            io:format("\nOutput after subscribing: ~p\n", [checkOutForConsideredUser2]),

                            ok = gen_tcp:send(socket, "Subscribed!"),

                            recieverListen(socket, table, [userID], clientSocketMapper)
                    end,
                    
                    ok = gen_tcp:send(socket, "Server processed subscription. Subscribed!"),
                    recieverListen(socket, table, [userID], clientSocketMapper);

                typeOfCommand == "question" ->
                    choice = binary_to_list(lists:nth(3, deets)),
                    userID = binary_to_list(lists:nth(2, deets)),
                    io:format("Query: The current username is -> ~p\n", [userID]),
                    if
                        choice == "1" ->
                            io:fwrite("My mentions!\n"),
                            myUserId = binary_to_list(lists:nth(4, deets)),
                            findUserID = ets:first(table),
                            consideredUser = string:strip(findUserID, right, $\n),
                            posts = searchAllposts("@", table, consideredUser, myUserId , []),
                            ok = gen_tcp:send(socket, posts);
                        choice == "2" ->
                            io:fwrite("Hashtag Search\n"),
                            findfindHashtag = binary_to_list(lists:nth(4, deets)),
                            findUserID = ets:first(table),
                            consideredUser = string:strip(findUserID, right, $\n),
                            io:format("findUserID: ~p\n", [consideredUser]),
                            posts = searchAllposts("#", table, consideredUser, findHashtag , []),
                            ok = gen_tcp:send(socket, posts);
                        true ->
                            findUserID = binary_to_list(lists:nth(4, deets)),
                            findUserID = ets:first(table),
                            consideredUser = string:strip(findUserID, right, $\n),
                            value = ets:lookup(table, consideredUser),
                            column3 = lists:nth(1, value),
                            column2 = element(2, column3),
                            column1 = maps:from_list(column2),                            
                            {ok, listOfposts} = maps:find("tweets",column1),
                            ok = gen_tcp:send(socket, listOfposts)
                    end,
                    recieverListen(socket, table, [userID], clientSocketMapper);
                true ->
                    io:fwrite("\n -------- \n")
            end;

        {error, closed} ->
            {ok, list_to_binary(Bs)};
        {error, Reason} ->
            io:fwrite("error"),
            io:fwrite(Reason)
    end.

searchAllposts(Symbol, table, Key, Word, Found) ->
    Search = string:concat(Symbol, Word),
    io:format("Word to be searched: ~p~n", [Search]),
    if
        Key == '$end_of_table' ->
            io:fwrite("Found tweets: ~p~n", [Found]),
            Found;
        true ->
            io:fwrite("Current Row key: ~p~n", [Key]),
            value = ets:lookup(table, Key),
            column3 = lists:nth(1, value),
            column2 = element(2, column3),
            column1 = maps:from_list(column2),                              
            {ok, listOfposts} = maps:find("tweets",column1),
            io:fwrite("listOfposts: ~p~n", [listOfposts]),
            Filteredposts = [S || S <- listOfposts, string:str(S, Search) > 0],
            io:fwrite("Filteredposts: ~p~n", [Filteredposts]),
            Found1 = Found ++ Filteredposts,
            CurrentRow_Key = ets:next(table, Key),
            searchAllposts(Symbol, table, CurrentRow_Key, Word, Found1)
    end.


sendMessage(socket, clientSocketMapper, post, Subscribers, userID) ->
    if
        Subscribers == [] ->
            io:fwrite("\nNo followers!\n");
        true ->

            [Client_To_Send | Remaining_List ] = Subscribers,
            io:format("Client to send: ~p\n", [Client_To_Send]),
            io:format("\nRemaining List: ~p~n",[Remaining_List]),
            Client_Socket_Row = ets:lookup(clientSocketMapper,Client_To_Send),
            column3 = lists:nth(1, Client_Socket_Row),
            Client_Socket = element(2, column3),
            io:format("\nClient socket: ~p~n",[Client_Socket]),
            
            ok = gen_tcp:send(Client_Socket, ["New post received!\n",userID,":",post]),
            ok = gen_tcp:send(socket, "Your post has been sent\n"),
            
            sendMessage(socket, clientSocketMapper, post, Remaining_List, userID)
    end,
    io:fwrite("Send message!\n").








