-module(client).
-export[start/0, userInputParser/2, recurser/1].

start() ->
    io:fwrite("\n\n New Client Turned On\n\n"),
    portNo = 1204,
    addrIP = "localhost",
    {ok, socket} = gen_tcp:connect(addrIP, portNo, [binary, {packet, 0}]),
    io:fwrite("\n\n Requested Server to start client\n\n"),
    spawn(client, userInputParser, [socket, "_"]),
    recurser(socket).

recurser(socket) ->
    receive
        {tcp, socket, deets} ->
            io:fwrite("Server Message Recieved\n"),
            io:fwrite(deets),
            recurser(socket);
        {tcp, closed, socket} ->  
            io:fwrite("Couldnt connect to the server")
        end.

userInputParser(socket, userIdentifier) ->
    io:fwrite("The commands are signup, post, repost, follow, question, signin, signout\n"),
    {ok, [commandEntered]} = io:fread("\nEnter the command: ", "~s\n"),
    io:fwrite(commandEntered),
    if 
        commandEntered == "signup" ->
            activeUserId = signup(socket);
        commandEntered == "post" ->
            if
                userIdentifier == "_" ->
                    io:fwrite("Please signup first!\n"),
                    activeUserId = userInputParser(socket, userIdentifier);
                true ->
                    postTweet(socket,userIdentifier),
                    activeUserId = userIdentifier
            end;
        commandEntered == "repost" ->
            if
                userIdentifier == "_" ->
                    io:fwrite("Please signup first!\n"),
                    activeUserId = userInputParser(socket, userIdentifier);
                true ->
                    repostTweet(socket, userIdentifier),
                    activeUserId = userIdentifier
            end;
        commandEntered == "follow" ->
            if
                userIdentifier == "_" ->
                    io:fwrite("Please signup first!\n"),
                    activeUserId = userInputParser(socket, userIdentifier);
                true ->
                    followUser(socket, userIdentifier),
                    activeUserId = userIdentifier
            end;
        commandEntered == "question" ->
            if
                userIdentifier == "_" ->
                    io:fwrite("Please signup first!\n"),
                    activeUserId = userInputParser(socket, userIdentifier);
                true ->
                    querySolutionFinder(socket, userIdentifier),
                    activeUserId = userIdentifier
            end;
        commandEntered == "signout" ->
            if
                userIdentifier == "_" ->
                    io:fwrite("Please signup first!\n"),
                    activeUserId = userInputParser(socket, userIdentifier);
                true ->
                    activeUserId = "_"
            end;
        commandEntered == "signin" ->
            activeUserId = signIn();
        true ->
            io:fwrite("Invalid command!, Please Enter another command!\n"),
            activeUserId = userInputParser(socket, userIdentifier)
    end,
    userInputParser(socket, activeUserId).


signup(socket) ->
    {ok, [userIdentifier]} = io:fread("\nEnter unique UserId: ", "~s\n"),
    %io:format("SELF: ~p\n", [self()]),
    ok = gen_tcp:send(socket, [["signup", ",", userIdentifier, ",", pid_to_list(self())]]),
    io:fwrite("\nYou have succesfully signed up and are logged in\n"),
    userIdentifier.

signIn() ->
    {ok, [userIdentifier]} = io:fread("\nEnter the UserId: ", "~s\n"),
    %io:format("SELF: ~p\n", [self()]),
    io:fwrite("\nAccount has been logged in\n"),
    userIdentifier.

postTweet(socket,userIdentifier) ->
    tweet = io:get_line("\nWhat do you want to post about ? \n"),
    ok = gen_tcp:send(socket, ["post", "," ,userIdentifier, ",", tweet]),
    io:fwrite("\nPost has been sent succesfully to your subscribers\n").

repostTweet(socket, userIdentifier) ->
    {ok, [userNameInterested]} = io:fread("\nWhose post do you wanna repost? ", "~s\n"),
    tweet = io:get_line("\nRe-enter the post as it is to confirm reposting!: "),
    ok = gen_tcp:send(socket, ["repost", "," ,userNameInterested, ",", userIdentifier,",",tweet]),
    io:fwrite("\nReposted\n").

followUser(socket, userIdentifier) ->
    userNameToFollow = io:get_line("\nEnter the userId you would want to follow: "),
    ok = gen_tcp:send(socket, ["follow", "," ,userIdentifier, ",", userNameToFollow]),
    io:fwrite("\nNow Following!\n").

querySolutionFinder(socket, userIdentifier) ->
    io:fwrite("\n Querying Options:\n"),
    io:fwrite("Choose from the following options ! \n"),
    io:fwrite("\n 1. Search for My Mentions\n"),
    io:fwrite("\n 2. Search for Hashtag\n"),
    io:fwrite("\n 3. Checkout Specified Users Tweets\n"),
    {ok, [choice]} = io:fread("\nSpecify the task number you want to perform: ", "~s\n"),
    if
        choice == "1" ->
            ok = gen_tcp:send(socket, ["question", "," ,userIdentifier, ",", "1", ",", userIdentifier]);
        choice == "2" ->
            {ok, [hashTag]} = io:fread("\nEnter the hahstag you want to search: ", "~s\n"),
            ok = gen_tcp:send(socket, ["question", "," ,userIdentifier, ",","2",",", hashTag]);
        true ->
            {ok, [Sub_UserName]} = io:fread("\nWhose tweets do you want? ", "~s\n"),
            ok = gen_tcp:send(socket, ["question", "," ,userIdentifier, ",", "3",",",Sub_UserName])
    end.