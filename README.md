## ETH_gas_analysis

In this Pluto notebook, we will visualize the variation in the base gas fee w.r.t. time
for a given number of blocks within the Ethereum network. Block data is retrieved from
[Infura](https://docs.infura.io/infura/getting-started) using their free API. Rate limit
for the free tier is set to 100,000 requests per day.

## API key

You will need to create an API key. It can be done for
free on the [Infura dashboard.](https://infura.io/dashboard)

## How to use?

Install Pluto.jl (if not done already) by executing the following commands in your Julia REPL:

    using Pkg
    Pkg.add("Pluto")
    using Pluto
    Pluto.run() 

Clone this repository and open **ETH_gas_notebook.jl** in your Pluto browser window. That's it!
You are good to go.