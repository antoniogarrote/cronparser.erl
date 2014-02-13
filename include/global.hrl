-include_lib("eunit/include/eunit.hrl").

-record(cron_entry, {minute_set, 
                     hour_set,
                     dom_set,
                     month_set,
                     dow_set,
                     
                     minute, 
                     hour,
                     dom,
                     month,
                     dow}).
