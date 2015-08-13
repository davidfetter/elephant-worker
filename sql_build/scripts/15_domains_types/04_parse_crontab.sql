-- Main source for decicions is man 5 crontab
CREATE OR REPLACE FUNCTION @extschema@.parse_crontab (schedule text, OUT minute int [], OUT hour int [], OUT dom int[], OUT month int[], OUT dow int[], OUT timezone text)
LANGUAGE plpgsql
AS
$BODY$
DECLARE
    entries         text [] := regexp_split_to_array(schedule, '\s+');
    entry           text;
BEGIN
    -- Allow some named entries, we transform them into the documented equivalent
    IF array_length (entries, 1) < 5 THEN
        IF array_length (entries, 1) = 1 THEN
            IF entries[1] = '@yearly' OR entries[1] = '@annually' THEN
                entries := ARRAY['0','0','1','1','*'];
            ELSIF entries[1] = '@monthly' THEN
                entries := ARRAY['0','0','1','*','*'];
            ELSIF entries[1] = '@weekly' THEN
                entries := ARRAY['0','0','*','*','0'];
            ELSIF entries[1] = '@daily' OR entries[1] = '@midnight' THEN
                entries := ARRAY['0','0','*','*','*'];
            ELSIF entries[1] = '@hourly' THEN
                entries := ARRAY['0','*','*','*','*'];
            ELSE
                RETURN ;
            END IF;
        ELSE
            RETURN;
        END IF;
    ELSIF array_length(entries, 1) > 5 THEN
        timezone := entries[6];
    END IF;

    -- We parse the 5 groups of crontab in a loop
    DECLARE
        cronfield_entry_groups text [];
        cronfield_values int [];
        entry_minvalues int [] := ARRAY[0,0,1,1,0];
        entry_maxvalues int [] := ARRAY[59,23,31,12,7];
        cronfield_entry_regexp text := '^(\*|(\d{1,2})(-(\d{1,2}))?)(\/(\d{1,2}))?$';
        cronfield_entry text;
        maxvalue int;
        minvalue int;
        min int;
        max int;
        step int;
        result int[];
    BEGIN
        FOR i IN 1..5 LOOP
            cronfield_values := '{}'; 
            minvalue         := entry_minvalues[i];
            maxvalue         := entry_maxvalues[i];
            FOREACH cronfield_entry IN ARRAY string_to_array(entries[i], ',')
            LOOP
                cronfield_entry_groups := regexp_matches(cronfield_entry, cronfield_entry_regexp);
                min := cronfield_entry_groups[2];
                step := coalesce(cronfield_entry_groups[6]::int,1);
                IF cronfield_entry_groups[1] = '*' THEN
                    min := minvalue;
                    max := maxvalue;
                ELSE
                    max := coalesce(cronfield_entry_groups[4]::int,min);
                END IF;

                IF max < min OR max > maxvalue OR min < minvalue THEN
                    RAISE SQLSTATE '22023' USING
                        MESSAGE = 'Invalid crontab parameter.',
                        DETAIL  = format('Range start: %s (%s), End range: %s (%s), Step: %s for crontab field: %s', min, minvalue, max, maxvalue, step, cronfield),
                        HINT    = 'Ensure range is ascending and that the ranges is within allowed bounds';
                END IF;

                cronfield_values := cronfield_values || array(SELECT generate_series(min, max, step));
            END LOOP;

            IF    i = 1 THEN
                minute := cronfield_values;
            ELSIF i = 2 THEN
                hour := cronfield_values;
            ELSIF i = 3 THEN
                dom := cronfield_values;
            ELSIF i = 4 THEN
                month := cronfield_values;
            ELSIF i = 5 THEN
                dow := cronfield_values;
            END IF;

        END LOOP;
    END; 

    -- Convert day 7 to day 0 (Sunday)
    dow :=  array(SELECT DISTINCT unnest(dow)%7 ORDER BY 1);

    -- To model the logic of cron, we empty on of the dow or dom arrays
    -- Logic (man 5 crontab):
    -- If both fields are restricted (ie, are not *), the command will be run when
    --     either field matches the current time.
    IF entries[5] = '*' AND entries[3] != '*' THEN
        dow := '{}'::int[];
    END IF;
    IF entries[3] = '*' AND entries[5] != '*' THEN
        dom := '{}'::int[];
    END IF;

    -- if any entry is null, the crontab is invalid
    IF minute IS NULL OR hour IS NULL OR dom IS NULL OR month IS NULL OR dow IS NULL THEN
        minute := null;
        hour   := null;
        dom    := null;
        month  := null;
        dow    := null;
        timezone := null;
    END IF;

    RETURN;
END;
$BODY$
SECURITY INVOKER
IMMUTABLE;

COMMENT ON FUNCTION @extschema@.parse_crontab (schedule text) IS
'Tries to parse a string into 5 int[] containing the expanded values for this entry.
Most crontab style entries are allowed.

Returns null on non-crontab format, raises exception on invalid crontab format.

Expanding 7-55/9 would for example become: {7,16,25,34,43,52}

This structure is useful for building an index which can be used for quering which job
should be run at a specific time.';
