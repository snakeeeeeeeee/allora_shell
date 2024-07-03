from flask import Flask, Response
import json
import pandas as pd
import torch
from chronos import ChronosPipeline
from okx import MarketData
import datetime

k_days = 60
bar = "1Dutc"

# create our Flask app
app = Flask(__name__)

# define the Hugging Face model we will use
model_name = "amazon/chronos-t5-tiny"


# define our endpoint
@app.route("/inference/<string:token>")
def get_inference(token):
    """Generate inference for given token."""
    try:
        # use a pipeline as a high-level helper
        pipeline = ChronosPipeline.from_pretrained(
            model_name,
            device_map="auto",  # auto, gpu, cpu
            torch_dtype=torch.bfloat16,
        )
    except Exception as e:
        return Response(json.dumps({"pipeline error": str(e)}), status=500, mimetype='application/json')

    df = get_kdata(token)

    # define the context and the prediction length
    context = torch.tensor(df["price"])
    prediction_length = 1

    try:
        forecast = pipeline.predict(context, prediction_length)  # shape [num_series, num_samples, prediction_length]
        print(forecast[0].mean().item())  # taking the mean of the forecasted prediction
        return Response(str(forecast[0].mean().item()), status=200)
    except Exception as e:
        return Response(json.dumps({"error": str(e)}), status=500, mimetype='application/json')


def get_kdata(token):
    # 实盘:0 , 模拟盘：1
    marketDataAPI = MarketData.MarketAPI(flag="0")
    today = datetime.datetime.now().date()
    today_start = datetime.datetime.combine(today, datetime.time.min)
    days_ago = today - datetime.timedelta(days=k_days)
    days_ago_start = datetime.datetime.combine(days_ago, datetime.time.min)
    after = int(today_start.timestamp() * 1000)
    before = int(days_ago_start.timestamp() * 1000)

    result = marketDataAPI.get_index_candlesticks(
        instId=f"{token.upper()}-USD",
        after=str(after),
        before=str(before),
        bar=bar,
        limit=10000
    )
    if not result or result.get("code") != "0":
        print("Failed to get okx k-data")
        return []

    data_map = {data[0]: float(data[4]) for data in reversed(result["data"])}

    # pandas
    df = pd.DataFrame(list(data_map.items()), columns=["date", "price"])
    df["date"] = pd.to_datetime(df["date"], unit='ms')
    print(df.tail(5))
    return df


if __name__ == '__main__':
    app.run(host="0.0.0.0", port=8000, debug=True)
