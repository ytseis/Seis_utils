using CSV, DataFrames, Dates, Printf

"""
    jma_to_csv(input_file::String, output_file::String)

Convert JMA hypocenter catalog to CSV format.

Input format: 年 月 日 時 分 秒 緯度 経度 深さ M 震央地名\n
Input format(en): year month day hour minute second lat lon dep Mjma location\n
Output format: date,time,lat,lon,dep,Mjma,location

Example:
2025  5  3 09:47 10.2  33°43.2'N 130°11.8'E    5     0.2  福岡県北西沖\n
-> 2025-05-03,09:47:10.2,33.7200,130.1967,5,0.2,福岡県北西沖
"""
function jma_to_csv(input_file::String, output_file::String)
    # Initialize DataFrame with appropriate column types
    df = DataFrame(
        date = Dates.Date[],
        time = Dates.Time[],
        lat = String[],
        lon = String[],
        dep = Float64[],
        Mjma = Float64[],
        location = String[]
    )

    # Process each line in the input file
    for line in readlines(input_file)
        # Skip empty lines and comments
        if isempty(line) || startswith(line, "#")
            continue
        end

        try
            # Parse date and time components
            fields = split(line)[1:5]
            year = parse(Int, fields[1])
            month = parse(Int, fields[2])
            day = parse(Int, fields[3])
            hour, minute = parse.(Int, split(fields[4], ':'))
            second, millisecond = parse.(Float64, split(fields[5], '.'))
            millisecond *= 100  # Convert to milliseconds

            date_val = Date(year, month, day)
            time_val = Time(hour, minute, Int(second), Int(millisecond))

            # Parse latitude (degrees and minutes to decimal)
            lat_deg = parse(Int, line[23:25])
            lat_min = parse(Float64, line[28:31]) / 60.0
            lat = lat_deg + lat_min
            if line[33] == 'S'  # Apply sign for Southern hemisphere
                lat = -lat
            end

            # Parse longitude (degrees and minutes to decimal)
            lon_deg = parse(Int, line[35:37])
            lon_min = parse(Float64, line[40:43]) / 60.0
            lon = lon_deg + lon_min
            if line[45] == 'W'  # Apply sign for Western hemisphere
                lon = -lon
            end

            # Round coordinates to 4 decimal places
            lat = round(lat, digits=4)
            lon = round(lon, digits=4)

            # Parse depth
            depth = parse(Float64, line[47:50])

            # Parse magnitude (handle missing values marked with "-")
            magnitude = if startswith(line[56:58], "-")
                NaN
            else
                parse(Float64, line[56:58])
            end

            # Extract location name
            location = strip(line[61:end])

            # Add record to DataFrame
            push!(df, (
                date = date_val,
                time = time_val,
                lat = @sprintf("%.4f", lat),
                lon = @sprintf("%.4f", lon),
                dep = depth,
                Mjma = magnitude,
                location = location
            ))

        catch e
            @warn "Failed to parse line: $line" exception=e
            continue
        end
    end

    # Write to CSV file
    CSV.write(output_file, df, writeheader=true)
    println("Successfully converted $(nrow(df)) records to $output_file")
end
