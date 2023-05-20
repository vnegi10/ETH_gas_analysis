### A Pluto.jl notebook ###
# v0.19.26

using Markdown
using InteractiveUtils

# ╔═╡ 8501799e-f65d-11ed-126f-b16149cf8823
using HTTP, JSON, DataFrames, Statistics, Dates, VegaLite, ProgressLogging

# ╔═╡ fafed3f4-e441-4d6e-bb6d-9c43b52a412d
md"
## Load packages
"

# ╔═╡ 90af42e4-ad0b-436f-b31a-71c1ea5b29c0
md"
## Get API key
"

# ╔═╡ 7e23173e-ed35-4686-90e8-94b4bfded77a
key = JSON.parsefile("/home/vikas/Documents/Infura_API_key.json")

# ╔═╡ a75bab4f-aeef-441d-bfab-b5b74a9b6cfc
const URL = "https://mainnet.infura.io/v3/$(key["API_key"])"

# ╔═╡ 09bdc200-7c9f-484b-91d0-48aba7a8b152
md"
## Make request
"

# ╔═╡ ae916260-2da6-4e14-bac7-b23f94e70b2c
function generate_body(RPC_name::String, params)

    body_dict = Dict("method"  => RPC_name, 
		             "params"  => params, 
		             "id"      => 1,
                     "jsonrpc" => "2.0")
	
    body = JSON.json(body_dict)

    return body
end

# ╔═╡ c6ae5bc5-6e32-4b3c-88e3-d0d48c8b8da5
function post_request(RPC_name::String; params)

    url = URL

    body = generate_body(RPC_name, params)
    headers = ["Content-Type" => "application/json"]

    response = HTTP.request(
        "POST",
        url,
        headers,
        body;
        verbose = 0,
        retries = 2
    )

    response_dict = String(response.body) |> JSON.parse

    return response_dict
end

# ╔═╡ 41f7b90d-0a4a-4501-9437-d668fccb3e38
md"
#### Batch
"

# ╔═╡ 222bf34f-d932-4c07-bb7a-2bd1ca5515eb
function convert_to_int(params::String)

    # Example for params input: "[500,501,502,503,504...]"

    all_params = split(params, ",")
    all_params[1] = strip(all_params[1], ['['])
    all_params[end] = strip(all_params[end], [']'])

    params_int = Int64[]

    for par in all_params
        push!(params_int, parse(Int64, par))
    end

    return params_int
end

# ╔═╡ bf6eae5f-11d0-4172-9226-9e8de5fb103e
function generate_body_batch(RPC_name::String, 
	                         i_blocks::UnitRange{Int64})

    bodies = Dict{String, Any}[]
	i = 1

	for i_block in i_blocks

		block = "0x" * string(i_block; base = 16)
        params = [block, false]		

        body_dict = Dict("method" => RPC_name, 
		                 "params" => params, 
		                 "id" => i,
		                 "jsonrpc" => "2.0")
		push!(bodies, body_dict)
		i += 1
	end
	
	return JSON.json(bodies)
end

# ╔═╡ 1912520f-90e0-4d01-baf2-9d028aadadbb
function post_request_batch(RPC_name::String, 
	                        i_blocks::UnitRange{Int64})

	url = URL
	bodies = generate_body_batch(RPC_name, i_blocks)
	headers = ["Content-Type" => "application/json"]

	response = HTTP.request(
        "POST",
        url,
        headers,
        bodies;
        verbose = 0,
        retries = 2
    )

	response_dicts = String(response.body) |> JSON.parse

    return response_dicts
end

# ╔═╡ 17b9d992-1ce0-4a83-a36a-93a47ddaea45
md"
## Get block information
"

# ╔═╡ 514db10b-0e68-4568-8e67-330bf8c2ae72
function show_latest_block()

    params = []
    response_dict = post_request("eth_blockNumber", params = params)

    result = response_dict["result"]

    return parse(Int, result[3:end], base = 16)

end

# ╔═╡ f47ebebd-ebb5-4d23-9706-673d27140527
function show_block_data(block_number::Int64)

    # https://ethereum.org/en/developers/docs/apis/json-rpc/#conventions
    # Encode as hex, prefix with "0x"
    block = "0x" * string(block_number; base = 16)

    params = [block, false]

    response_dict = post_request("eth_getBlockByNumber", params = params)

    return response_dict["result"]
end

# ╔═╡ d80ad065-b183-4831-9d6f-f9a2ebd62c74
latest_block = show_latest_block()

# ╔═╡ cd582be9-eee3-4185-8366-d9b5879e99c0
block_data = show_block_data(latest_block)

# ╔═╡ ac45e3c8-9bb5-4cd0-bcbf-dd3aa4e1f7e9
md"
#### Base fee
"

# ╔═╡ 5100ab58-d5ec-4ba4-8a90-abb03d580294
function get_basefee_step(num_blocks::Int64, step_size::Int64)

    block_latest = show_latest_block()

    block_start = block_latest - num_blocks

    base_fee = Float64[]
    time = DateTime[]	
	num_tx = Int64[]

    for i_block in range(start = block_start, stop = block_latest, step = step_size)

		result = show_block_data(i_block)

		# 1 gwei = 10^9 wei
		fee_gwei = parse(Int, result["baseFeePerGas"][3:end], base = 16)/10^9
	    push!(base_fee, fee_gwei)

		push!(num_tx, result["transactions"] |> length)

	    block_time = result["timestamp"]
	    unix_time = parse(Int, block_time[3:end], base = 16)

	    push!(time, unix2datetime(unix_time))

    end

    df_fee = DataFrame(block_time = time, 
		               base_fee = base_fee,
	                   num_tx = num_tx)

    return df_fee
end

# ╔═╡ 7c0d4c3c-cef2-48ef-a915-d77cf4b05e77
function get_basefee_all(num_blocks::Int64)

    block_latest = show_latest_block()
    block_start = block_latest - num_blocks

    base_fee = Float64[]
    time = DateTime[]		

    @progress for i_block in block_start:block_latest

		result = show_block_data(i_block)

		# 1 gwei = 10^9 wei
		fee_gwei = parse(Int, result["baseFeePerGas"][3:end], base = 16)/10^9
	    push!(base_fee, fee_gwei)		

	    block_time = result["timestamp"]
	    unix_time = parse(Int, block_time[3:end], base = 16)

	    push!(time, unix2datetime(unix_time))

    end

    df_fee = DataFrame(block_time = time, 
		               base_fee = base_fee)	                   

    return df_fee
end

# ╔═╡ 2c5f4391-8d30-4aab-b5a4-694c18089704
function get_hourly_fee(df_fee::DataFrame)

    time = DateTime[]
	avg_fee = Float64[]

	all_dates = Dates.yearmonthday.(df_fee[!, :block_time]) |> unique

	for one_day in all_dates
		df_filter_1 = filter(row -> Dates.yearmonthday(row.block_time) == one_day,
		                     df_fee)

		all_hours = Dates.hour.(df_filter_1[!, :block_time]) |> unique

		for one_hour in all_hours
			df_filter_2 = filter(row -> Dates.hour(row.block_time) == one_hour,
			                     df_filter_1)

			push!(time, DateTime(one_day[1], 
			                     one_day[2],
			                     one_day[3],
			                     one_hour))

			push!(avg_fee, mean(df_filter_2[!, :base_fee]))
		end
	end

	df_avg_fee = DataFrame(block_hour = time,
	                       avg_fee = avg_fee)

	return df_avg_fee

end	

# ╔═╡ 769b9b21-0771-43cc-99f6-6d4a7324cd3b
md"
#### Batch mode
"

# ╔═╡ a1fbc96e-323d-4d88-8c6b-4e626876b3a6
function get_block_data_batch(num_blocks::Int64, batchsize::Int64)

	@assert num_blocks > batchsize "number of blocks is smaller than the batch size"

    block_end = show_latest_block()
    block_start = block_end - num_blocks

	response_dicts = ""
	all_results = Any[]
    i = block_start
    last_batch = false

	while i ≤ block_end

        j = i + batchsize

        if j ≥ block_end
            j = block_end
            last_batch = true
        end
		
        i_blocks = i:j

        try
            response_dicts = post_request_batch("eth_getBlockByNumber", i_blocks)
        catch e
            @info "Ran into error $(e)"
            @info "Could not fetch data for blocks $(i) to $(j), will continue to next batch!"
            i = j + 1
            continue
        end

		for response in response_dicts
			push!(all_results, response["result"])
		end

		if last_batch
            break
        end		

        i = j + 1

	end

	return all_results

end    

# ╔═╡ f4392869-0d34-4f89-8bb2-c5a76545de53
function get_basefee_all_batch(num_blocks::Int64, batchsize::Int64)

	all_results = get_block_data_batch(num_blocks, batchsize)

	base_fee = Float64[]
    time = DateTime[]		

	for result in all_results

		# 1 gwei = 10^9 wei
		fee_gwei = parse(Int, result["baseFeePerGas"][3:end], base = 16)/10^9
	    push!(base_fee, fee_gwei)		

	    block_time = result["timestamp"]
	    unix_time = parse(Int, block_time[3:end], base = 16)

	    push!(time, unix2datetime(unix_time))

	end

	df_fee = DataFrame(block_time = time, 
		               base_fee = base_fee)	                   

    return df_fee

end

# ╔═╡ 9a7fcc43-3c0c-41b1-bef1-c401f7e15e6e
#results = get_block_data_batch(100, 10)

# ╔═╡ cb89afd0-2043-4668-ba6e-3c2aa869e4e1
@time df_fee_single = get_basefee_all(100);

# ╔═╡ 8bad604b-84d2-4496-9e44-c8c37252bb71
@time df_fee_batch = get_basefee_all_batch(100, 25);

# ╔═╡ dd2f430d-c587-4473-b235-731d7047ccfb
#df_hourly = get_hourly_fee(df_fee)

# ╔═╡ 06972db0-38ba-48f3-b0c4-26b273ec59de
@time df_fee = get_basefee_all_batch(50_000, 1000);

# ╔═╡ 4c9253dc-4ce1-4fc2-8011-9b4ab30f01dd
md"
## Plot data
"

# ╔═╡ eef580f1-d8e0-4b34-bee0-7efadb6f420c
function plot_block_fee(df_fee::DataFrame)

	df_hourly = get_hourly_fee(df_fee)

    figure = df_hourly |>
	     @vlplot(mark = {:line, 
			             point = {filled = false, fill = :white},
			             interpolate = "monotone"},
	     x = {:block_hour, 
			  "axis" = {"title" = "Block time",
		      "labelFontSize" = 10, 
			  "titleFontSize" = 12,
			  "axis" = {"format" = "%D"}}},
	     y = {:avg_fee, 
		      "axis" = {"title" = "Base fee [gwei]",
		      "labelFontSize" = 10, 
			  "titleFontSize" = 12 }},
	     width = 500, 
	     height = 300,
	    "title" = {"text" = "Hourly avg. block base fee", 
		           "fontSize" = 14})

    return figure
end

# ╔═╡ 346fa27f-7ef2-4a02-af9c-8d64f03a0d5c
plot_block_fee(df_fee)

# ╔═╡ b785667b-cfd8-463a-9595-a8fc2f54921f
function plot_block_fee_trail(df_fee::DataFrame)

	df_hourly = get_hourly_fee(df_fee)

    figure = df_hourly |>
	     @vlplot(:trail,			 
	     x = {:block_hour, 
			  "axis" = {"title" = "Block time",
		      "labelFontSize" = 10, 
			  "titleFontSize" = 12}},
	     y = {:avg_fee, 
		      "axis" = {"title" = "Base fee [gwei]",
		      "labelFontSize" = 10, 
			  "titleFontSize" = 12 }},
		 size = {"field" = "avg_fee", 
		         "legend" = "null"},			  
	     width = 500, 
	     height = 300,
	    "title" = {"text" = "Hourly avg. block base fee", 
		           "fontSize" = 14})

    return figure
end

# ╔═╡ 73c43351-e461-48f8-83b0-18c2d15cd225
plot_block_fee_trail(df_fee)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Dates = "ade2ca70-3891-5945-98fb-dc099432e06a"
HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"
JSON = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
ProgressLogging = "33c8b6b6-d38a-422a-b730-caa89a2f386c"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
VegaLite = "112f6efa-9a02-5b7d-90c0-432ed331239a"

[compat]
DataFrames = "~1.5.0"
HTTP = "~1.9.4"
JSON = "~0.21.4"
ProgressLogging = "~0.1.4"
VegaLite = "~3.2.2"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.0"
manifest_format = "2.0"
project_hash = "72d41adbf0adf541efc3e384f506d4d31733497a"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BitFlags]]
git-tree-sha1 = "43b1a4a8f797c1cddadf60499a8a077d4af2cd2d"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.7"

[[deps.BufferedStreams]]
git-tree-sha1 = "bb065b14d7f941b8617bc323063dbe79f55d16ea"
uuid = "e1450e63-4bb3-523b-b2a4-4ffa8c0fd77d"
version = "1.1.0"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "9c209fb7536406834aa938fb149964b985de6c83"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.1"

[[deps.Compat]]
deps = ["UUIDs"]
git-tree-sha1 = "7a60c856b9fa189eb34f5f8a6f6b5529b7942957"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.6.1"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.2+0"

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "96d823b94ba8d187a6d8f0826e731195a74b90e9"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.2.0"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "738fec4d684a9a6ee9598a8bfee305b26831f28c"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.5.2"

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseStaticArraysExt = "StaticArrays"

    [deps.ConstructionBase.weakdeps]
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "8da84edb865b0b5b0100c0666a9bc9a0b71c553c"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.15.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Random", "Reexport", "SentinelArrays", "SnoopPrecompile", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "aa51303df86f8626a962fccb878430cdb0a97eee"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.5.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "d1fff3a548102f48987a52a2e0d114fa97d730f0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.13"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.DataValues]]
deps = ["DataValueInterfaces", "Dates"]
git-tree-sha1 = "d88a19299eba280a6d062e135a43f00323ae70bf"
uuid = "e7dc6d0d-1eca-5fa6-8ad6-5aecde8b7ea5"
version = "0.4.13"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "299dc33549f68299137e51e6d49a13b5b1da9673"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.16.1"

[[deps.FilePaths]]
deps = ["FilePathsBase", "MacroTools", "Reexport", "Requires"]
git-tree-sha1 = "919d9412dbf53a2e6fe74af62a73ceed0bce0629"
uuid = "8fc22ac5-c921-52a6-82fd-178b2807b824"
version = "0.8.3"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "e27c4ebe80e8699540f2d6c805cc12203b614f12"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.20"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "ConcurrentUtilities", "Dates", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "41f7dfb2b20e7e8bf64f6b6fae98f4d2df027b06"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.9.4"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "9cc2baf75c6d09f9da536ddf58eb2f29dedaf461"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InvertedIndices]]
git-tree-sha1 = "0dc7b50b8d436461be01300fd8cd45aa0274b038"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JSONSchema]]
deps = ["Downloads", "HTTP", "JSON", "URIs"]
git-tree-sha1 = "58cb291b01508293f7a9dc88325bc00d797cf04d"
uuid = "7d188eb4-7ad8-530c-ae41-71a32a6d4692"
version = "1.1.0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "cedb76b37bc5a6c702ade66be44f831fa23c681e"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.0.0"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "42324d08725e200c23d4dfb549e0d5d89dede2d2"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.10"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "Random", "Sockets"]
git-tree-sha1 = "03a9b9718f5682ecb107ac9f7308991db4ce395b"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.7"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "f66bdc5de519e8f8ae43bdc598782d35a25b1272"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.1.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.10.11"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.NodeJS]]
deps = ["Pkg"]
git-tree-sha1 = "bf1f49fd62754064bc42490a8ddc2aa3694a8e7a"
uuid = "2bd173c7-0d6d-553b-b6af-13a54713934c"
version = "2.0.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.21+4"

[[deps.OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "51901a49222b09e3743c65b8847687ae5fc78eb2"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.4.1"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6cc6366a14dbe47e5fc8f3cbe2816b1185ef5fc4"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.0.8+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "d321bf2de576bf25ec4d3e4360faca399afca282"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.0"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "a5aef8d4a6e8d81f171b2bd4be5265b01384c74c"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.5.10"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.9.0"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a6062fe4063cdafe78f4a0a81cfffb89721b30e7"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.2"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "259e206946c293698122f63e2b513a7c99a244e8"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.1.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "7eb1686b4f04b82f96ed7a4ea5890a4f0c7a09f1"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.0"

[[deps.PrettyTables]]
deps = ["Crayons", "Formatting", "LaTeXStrings", "Markdown", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "213579618ec1f42dea7dd637a42785a608b1ea9c"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.2.4"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.ProgressLogging]]
deps = ["Logging", "SHA", "UUIDs"]
git-tree-sha1 = "80d919dee55b9c50e8d9e2da5eeafff3fe58b539"
uuid = "33c8b6b6-d38a-422a-b730-caa89a2f386c"
version = "0.1.4"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "77d3c4726515dca71f6d80fbb5e251088defe305"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.3.18"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "e2cc6d8c88613c05e1defb55170bf5ff211fbeac"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.1"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "874e8867b33a00e784c8a7e4b60afe9e037b74e1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.1.0"

[[deps.SnoopPrecompile]]
deps = ["Preferences"]
git-tree-sha1 = "e760a70afdcd461cf01a575947738d359234665c"
uuid = "66db9d55-30c0-4569-8b51-7e840670fc0c"
version = "1.0.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "a4ada03f999bd01b3a25dcaa30b2d929fe537e00"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.1.0"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6b7ba252635a5eff6a0b0664a41ee140a1c9e72a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.9.0"

[[deps.StringManipulation]]
git-tree-sha1 = "46da2434b41f41ac3594ee9816ce5541c6096123"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.3.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "Pkg", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "5.10.1+6"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.TableTraitsUtils]]
deps = ["DataValues", "IteratorInterfaceExtensions", "Missings", "TableTraits"]
git-tree-sha1 = "78fecfe140d7abb480b53a44f3f85b6aa373c293"
uuid = "382cd787-c1b6-5bf2-a167-d5b971a19bda"
version = "1.0.2"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "1544b926975372da01227b382066ab70e574a3ec"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.10.1"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "9a6ae7ed916312b41236fcef7e0af564ef934769"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.13"

[[deps.URIParser]]
deps = ["Unicode"]
git-tree-sha1 = "53a9f49546b8d2dd2e688d216421d050c9a31d0d"
uuid = "30578b45-9adc-5946-b283-645ec420af67"
version = "0.4.1"

[[deps.URIs]]
git-tree-sha1 = "074f993b0ca030848b897beff716d93aca60f06a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.4.2"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Vega]]
deps = ["BufferedStreams", "DataStructures", "DataValues", "Dates", "FileIO", "FilePaths", "IteratorInterfaceExtensions", "JSON", "JSONSchema", "MacroTools", "NodeJS", "Pkg", "REPL", "Random", "Setfield", "TableTraits", "TableTraitsUtils", "URIParser"]
git-tree-sha1 = "9d5c73642d291cb5aa34eb47b9d71428c4132398"
uuid = "239c3e63-733f-47ad-beb7-a12fde22c578"
version = "2.6.2"

[[deps.VegaLite]]
deps = ["Base64", "BufferedStreams", "DataStructures", "DataValues", "Dates", "FileIO", "FilePaths", "IteratorInterfaceExtensions", "JSON", "MacroTools", "NodeJS", "Pkg", "REPL", "Random", "TableTraits", "TableTraitsUtils", "URIParser", "Vega"]
git-tree-sha1 = "3dc847d4bc5766172b4646fd7fe6a99bff53ac7b"
uuid = "112f6efa-9a02-5b7d-90c0-432ed331239a"
version = "3.2.2"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.7.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"
"""

# ╔═╡ Cell order:
# ╟─fafed3f4-e441-4d6e-bb6d-9c43b52a412d
# ╠═8501799e-f65d-11ed-126f-b16149cf8823
# ╟─90af42e4-ad0b-436f-b31a-71c1ea5b29c0
# ╠═7e23173e-ed35-4686-90e8-94b4bfded77a
# ╠═a75bab4f-aeef-441d-bfab-b5b74a9b6cfc
# ╟─09bdc200-7c9f-484b-91d0-48aba7a8b152
# ╟─ae916260-2da6-4e14-bac7-b23f94e70b2c
# ╟─c6ae5bc5-6e32-4b3c-88e3-d0d48c8b8da5
# ╟─41f7b90d-0a4a-4501-9437-d668fccb3e38
# ╟─222bf34f-d932-4c07-bb7a-2bd1ca5515eb
# ╟─bf6eae5f-11d0-4172-9226-9e8de5fb103e
# ╟─1912520f-90e0-4d01-baf2-9d028aadadbb
# ╟─17b9d992-1ce0-4a83-a36a-93a47ddaea45
# ╟─514db10b-0e68-4568-8e67-330bf8c2ae72
# ╟─f47ebebd-ebb5-4d23-9706-673d27140527
# ╠═d80ad065-b183-4831-9d6f-f9a2ebd62c74
# ╠═cd582be9-eee3-4185-8366-d9b5879e99c0
# ╟─ac45e3c8-9bb5-4cd0-bcbf-dd3aa4e1f7e9
# ╟─5100ab58-d5ec-4ba4-8a90-abb03d580294
# ╟─7c0d4c3c-cef2-48ef-a915-d77cf4b05e77
# ╟─2c5f4391-8d30-4aab-b5a4-694c18089704
# ╟─769b9b21-0771-43cc-99f6-6d4a7324cd3b
# ╟─a1fbc96e-323d-4d88-8c6b-4e626876b3a6
# ╟─f4392869-0d34-4f89-8bb2-c5a76545de53
# ╠═9a7fcc43-3c0c-41b1-bef1-c401f7e15e6e
# ╠═cb89afd0-2043-4668-ba6e-3c2aa869e4e1
# ╠═8bad604b-84d2-4496-9e44-c8c37252bb71
# ╠═dd2f430d-c587-4473-b235-731d7047ccfb
# ╠═06972db0-38ba-48f3-b0c4-26b273ec59de
# ╟─4c9253dc-4ce1-4fc2-8011-9b4ab30f01dd
# ╟─eef580f1-d8e0-4b34-bee0-7efadb6f420c
# ╠═346fa27f-7ef2-4a02-af9c-8d64f03a0d5c
# ╟─b785667b-cfd8-463a-9595-a8fc2f54921f
# ╠═73c43351-e461-48f8-83b0-18c2d15cd225
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
