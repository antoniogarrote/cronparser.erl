-module(cronparser) .
-include("global.hrl") .

-export([time_specs/1,next/2]) .
-ifdef(TEST).
-compile(export_all).
-endif.

-define(PARSE_SYMBOLS,[
                       %% Months
                       ["jan", "1"],
                       ["feb","2"],
                       ["mar","3"],
                       ["apr","4"],
                       ["may","5"],
                       ["jun","6"],
                       ["jul","7"],
                       ["aug","8"],
                       ["sep","9"],
                       ["oct","10"],
                       ["nov","11"],
                       ["dec","12"],

                       %% Days of week
                       ["sun","0"],
                       ["mon","1"],
                       ["tue","2"],
                       ["wed","3"],
                       ["thu","4"],
                       ["fri","5"],
                       ["sat","6"] 

                      ]) .

-define(SUBELEMENT_REGEX,"^(\\d+)(-(\\d+)(/(\\d+))?)?$") .
        
%% Parser

substitute_parse_symbols(ToParse) ->
    substitute_parse_symbols(string:to_lower(ToParse), ?PARSE_SYMBOLS) .
substitute_parse_symbols(ToParse,[]) ->
    ToParse ;
substitute_parse_symbols(ToParse,[[ToReplace, Replacement]|T]) ->
    Replaced = re:replace(ToParse, ToReplace, Replacement,[global,{return,list}]),
    substitute_parse_symbols(Replaced, T) .


parse_elements(ToParse, MinRange, MaxRange) ->
    Elements = string:tokens(ToParse,","),
    Times = lists:map(fun(Element) -> 
                      parse_element(Element, MinRange, MaxRange) 
                    end, 
                    Elements),
    lists:flatten(Times).

parse_element(Element, MinRange, MaxRange) ->
    case re:run(Element,"^\\*") of

        {match,_} ->

            Len = string:len(Element),
            Step = if Len =:= 1 -> 1;
                      Len =/= 1 -> list_to_integer(string:substr(Element,3,Len))
                   end,
            stepped_range(MinRange, MaxRange, Step);                          

        _         ->

            case re:run(Element, ?SUBELEMENT_REGEX, [{capture,all,list}]) of
                {match, [_,Numeric]} ->
                    [list_to_integer(Numeric)] ;
                {match, [_,StartRange,_,EndRange]} ->
                    stepped_range(list_to_integer(StartRange),list_to_integer(EndRange), 1) ;
                {match, [_,StartRange,_,EndRange,_,Step]} ->
                    stepped_range(list_to_integer(StartRange),list_to_integer(EndRange), list_to_integer(Step)) ;
                nomatch ->
                    throw("Bad Vixie-style specification")
            end
    end .

stepped_range(StartRange, EndRange, Step) ->
    Len = EndRange - StartRange,
    Num = trunc(Len / Step),
    Iterations = lists:seq(0,Num),
    lists:map(fun(Iteration) ->
                      StartRange + Step * Iteration
              end,
              Iterations) .
    
            
time_specs(Source) ->
    ToParse = substitute_parse_symbols(Source),
    [Minute, Hour, Dom, Month, Dow] = re:split(ToParse,"\\s+",[{return,list}]),    

    MinuteVals = lists:sort(lists:flatten(parse_elements(Minute, 0, 59))),
    HourVals   = lists:sort(lists:flatten(parse_elements(Hour, 0, 23))),
    DomVals    = lists:sort(lists:flatten(parse_elements(Dom, 1, 31))),
    MonthVals  = lists:sort(lists:flatten(parse_elements(Month, 1, 12))),
    DowVals    = lists:sort(lists:flatten(parse_elements(Dow, 0, 6))),

    #cron_entry{
       minute_set = sets:from_list(MinuteVals),
       hour_set   = sets:from_list(HourVals),
       dom_set    = sets:from_list(DomVals),
       month_set  = sets:from_list(MonthVals),
       dow_set    = sets:from_list(DowVals),

       minute = MinuteVals,
       hour   = HourVals,
       dom    = DomVals,
       month  = MonthVals,
       dow    = DowVals
    } .

%% Time functions

find_best_next(Current, Allowed, Dir) ->
    Values = case Dir of
                 next ->
                     lists:filter(fun(X) -> X > Current end,
                                  Allowed);
                 prev ->
                     lists:filter(fun(X) -> X < Current end,
                                  lists:reverse(Allowed))
             end,
    case length(Values) of
        0 ->
            nil;
        _ ->
            lists:nth(1,Values) 
    end .
                         
compute_next_time(Now,Spec) ->
    {Date,{Hour,Minute,Seconds}} = Now,
    #cron_entry{minute=MinuteVals,hour=HourVals,hour_set=HoursSet} = Spec,
    [NextMinute,NextHour,NextDate] = case find_best_next(Minute, MinuteVals, next) of
                                         nil    ->
                                             case find_best_next(Hour, HourVals, next) of
                                                 nil   ->
                                                     [hd(MinuteVals), hd(HourVals), edate:shift(Date,1,day)] ;
                                                 ValueHour ->
                                                     [hd(MinuteVals), ValueHour, Date]
                                             end;
                                         ValueMin ->
                                             case sets:is_element(Hour,HoursSet) of
                                                 true  ->
                                                     [ValueMin,Hour,Date];
                                                 false ->
                                                     case find_best_next(Hour, HourVals, next) of
                                                         nil ->
                                                             [hd(MinuteVals), hd(HourVals), edate:shift(Date,1,day)] ;
                                                         ValueHour ->
                                                             [hd(MinuteVals), ValueHour, Date]
                                                     end
                                             end
                                     end,
    {NextDate,{NextHour,NextMinute,Seconds}} .
                         
day_of_week(Date) ->
    case calendar:day_of_the_week(Date) of
        7      -> 0 ;
        Value  -> Value
    end.
    
compute_next_date(Now,Spec) ->
    {{Year,Month,Day},Time} = Now,
    #cron_entry{month=MonthVals,dom=DayVals,dow_set=DaysOfWeekSet,month_set=MonthsSet} = Spec,
    #cron_entry{hour=HourVals,minute=MinuteVals} = Spec,
    {NextDate,NextTime} = case find_best_next(Day,DayVals,next) of
                              nil    ->
                                  case find_best_next(Month,MonthVals,next) of
                                      nil -> % first day, first month -> next year
                                          {{Year+1, hd(MonthVals), hd(DayVals)},{hd(HourVals),hd(MinuteVals),0}} ;
                                      MonthVal -> % first day -> next month
                                          {{Year, MonthVal, hd(DayVals)},{hd(HourVals),hd(MinuteVals),0}}
                                  end ;
                              DayVal ->
                                  case sets:is_element(Month,MonthsSet) of
                                      true  ->
                                          {{Year, Month, DayVal},Time} ;
                                      false ->
                                          case find_best_next(Month,MonthVals,next) of
                                              nil -> % first day, first month -> next year
                                                  {{Year+1, hd(MonthVals), hd(DayVals)},{hd(HourVals),hd(MinuteVals),0}} ;
                                              MonthVal -> % first day -> next month
                                                  {{Year, MonthVal, hd(DayVals)},{hd(HourVals),hd(MinuteVals),0}}
                                          end 
                                  end
                          end,
    try day_of_week(NextDate) of
        DayOfWeek ->
            case sets:is_element(DayOfWeek,DaysOfWeekSet) of
                true  ->
                    {NextDate,NextTime} ;
                false ->
                    compute_next_date({NextDate,NextTime},Spec)
            end
    catch
        _ ->
            {ThisYear, ThisMonth, _} = NextDate,
            case find_best_next(ThisMonth, MonthVals, next) of
                nil       ->
                    compute_next_date({{ThisYear+1,hd(MonthVals),hd(DayVals)},{hd(HourVals),hd(MinuteVals),0}},Spec) ;
                SafeMonth ->
                    compute_next_date({{ThisYear,SafeMonth,hd(DayVals)},{hd(HourVals),hd(MinuteVals),0}},Spec) 
            end
    end .
 
valid_date({{Year,Month,Day},_},
           #cron_entry{month_set=MonthSet, dom_set=DomSet, dow_set=DowSet}) ->
    case sets:is_element(Month,MonthSet) of
        true  ->
            case sets:is_element(Day, DomSet) of
                true  ->
                    case sets:is_element(day_of_week({Year,Month,Day}),DowSet) of
                        true  ->
                            true ;
                        false ->
                            false
                    end;
                false ->
                    false
            end;
        false ->
            false
    end .
                        
                     
    
next(Now,Specs) ->
    NextTime = compute_next_time(Now,Specs),
    case valid_date(NextTime,Specs) of
        true  -> 
            NextTime ;
        false ->
            {Date,_} = NextTime,
            #cron_entry{hour=HourVals,minute=MinuteVals} = Specs,
            compute_next_date({Date,{hd(HourVals),hd(MinuteVals),0}},Specs)
    end .
