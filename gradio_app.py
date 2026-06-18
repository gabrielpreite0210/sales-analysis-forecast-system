import gradio as gr
import joblib
import pandas as pd

# Load the model
model=joblib.load('model/forecast_model.pkl')

# Forecast function
def forecast(periods):
    future= model.make_future_dataframe(periods=int(periods), freq='W')
    forecast= model.predict(future)

    # result output
    result= forecast[['ds', 'yhat']].tail(int(periods)) # to show only the last n rows (future)

    # plot
    fig1= model.plot(forecast)
    fig2= model.plot_components(forecast)

    return result, fig1, fig2


# Gradio Interface
with gr.Blocks() as app:
    gr.Markdown("""
    <div style="text-align: center;">
        <h1>📈 Walmart Weekly Sales Forecasting</h1>
        <h3>Enter the number of weeks to forecast and click 'Submit' to see the results and plot</h3>
        <p>📊 Historical trends • 📅 Weekly forecasts</p>
    </div>

    ---

    ### Forecast Output Guide

    - **ds** → Forecast date (week ending date)
    - **yhat** → Predicted weekly sales

    💡 Sales values are reported in **US dollars**.

    Example:

    - `47,932,082` = approximately **$47.9 million** in weekly sales.
    """)

    with gr.Row():
        periods= gr.Slider(1, 52, value=12, step=1, label='Weeks to forecast') # maximum 52 weeks (1 year)
        button= gr.Button('Submit')

    with gr.Row():
        output_result= gr.Dataframe(label='Forecast Results')
        output_plot1= gr.Plot(label='Forecast Plot')
        output_plot2= gr.Plot(label='Forecast Components')

        # action fo the button
        button.click(
            fn= forecast,
            inputs= periods,
            outputs= [output_result, output_plot1, output_plot2]
        )

app.launch(share=True)