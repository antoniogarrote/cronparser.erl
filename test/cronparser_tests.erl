-module(cronparser_tests) .
-include("global.hrl") .

substitue_parse_symbols_test() ->
    Res = cronparser:substitute_parse_symbols("jan feb mar 0 1 2 sun mon tue"),
    ?assert(string:equal(Res, "1 2 3 0 1 2 0 1 2")) .

parse_element_test() ->
    ?assert(cronparser:parse_elements("*",0,59) =:= lists:seq(0,59)),
    ?assert(cronparser:parse_elements("*/10",0,59) =:= [0,10,20,30,40,50]),
    ?assert(cronparser:parse_elements("10",0,59) =:= [10]),
    ?assert(cronparser:parse_elements("10,30",0,59) =:= [10,30]),
    ?assert(cronparser:parse_elements("10-15",0,59) =:= [10,11,12,13,14,15]),
    ?assert(cronparser:parse_elements("10-40/10",0,59) =:= [10,20,30,40]) .

compute_next_time_test() ->
    Specs = ["* * * * *",
             "* * * * *",
             "* * * * *",
             "*/15 * * * *",
             "*/15,25 * * * *",
             "30 3,6,9 * * *",
             "30 9 * * *",
             "30 9 * * *",
             "30 9 * * *",
             "0 9 * * *",
             "* * 12 * *",
             "* * * * 1,3",
             "* * * * MON,WED",
             "0 0 1 1 *",
             "0 0 * * 1",
             "0 0 * * 1",
             "45 23 7 3 *",
             "0 0 1 jun *",
             "0 0 1 may,jul *",
             "0 0 1 MAY,JUL *"
            ],

    Nows = [{{2011,8,15},{12,0,0}},
            {{2011,8,15},{2,25,0}},
            {{2011,8,15},{2,59,0}},
            {{2011,8,15},{2,2,0}},
            {{2011,8,15},{2,15,0}},
            {{2011,8,15},{2,15,0}},
            {{2011,8,15},{10,15,0}},
            {{2011,8,31},{10,15,0}},
            {{2011,9,30},{10,15,0}},
            {{2011,12,31},{10,15,0}},
            {{2010,4,15},{10,15,0}},
            {{2010,4,15},{10,15,0}},
            {{2010,4,15},{10,15,0}},
            {{2010,4,15},{10,15,0}},
            {{2011,8,1},{0,0,0}},
            {{2011,7,25},{0,0,0}},
            {{2011,1,1},{0,0,0}},
            {{2013,5,14},{11,20,0}},
            {{2013,5,14},{15,0,0}},
            {{2013,5,14},{15,0,0}}
           ],

    Expecteds = [{{2011,8,15},{12,1,0}},
                 {{2011,8,15},{2,26,0}},
                 {{2011,8,15},{3,0,0}},
                 {{2011,8,15},{2,15,0}},
                 {{2011,8,15},{2,25,0}},
                 {{2011,8,15},{3,30,0}},
                 {{2011,8,16},{9,30,0}},
                 {{2011,9,1},{9,30,0}},
                 {{2011,10,1},{9,30,0}},
                 {{2012,1,1},{9,0,0}},
                 {{2010,5,12},{0,0,0}},
                 {{2010,4,19},{0,0,0}},
                 {{2010,4,19},{0,0,0}},
                 {{2011,1,1},{0,0,0}},
                 {{2011,8,8},{0,0,0}},
                 {{2011,8,1},{0,0,0}},
                 {{2011,3,7},{23,45,0}},
                 {{2013,6,1},{0,0,0}},
                 {{2013,7,1},{0,0,0}},
                 {{2013,7,1},{0,0,0}}
                ],

    ParsedSpecs = [cronparser:time_specs(S) || S <- Specs],

    Incoming = lists:zip3(ParsedSpecs,Nows,Expecteds),

    lists:foreach(fun({Spec,Now,Expected}) ->
                          io:format("TYRING ~p ... ",[Now]),
                          Next = cronparser:next(Now,Spec),
                          io:format("FOUND ~p FOR ~p\n",[Next,Expected]),
                          ?assert(Next =:= Expected)
                  end,
                  Incoming) .
