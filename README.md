# Hello World

This tutorial will demonstrate how to get Dapr running locally on your machine. You'll be deploying a Ballerina app that subscribes to order messages and persists them. The following architecture diagram illustrates the components that make up the first part sample: 

![Architecture Diagram](./img/Architecture_Diagram.png)

Later on, you'll deploy a Python app to act as the publisher. The architecture diagram below shows the addition of the new component:

![Architecture Diagram Final](./img/Architecture_Diagram_B.png)

## Prerequisites
This quickstart requires you to have the following installed on your machine:
- [Docker](https://docs.docker.com/)
- [Ballerina](https://dist-dev.ballerina.io/downloads/swan-lake-beta1/ballerina-linux-installer-x64-swan-lake-beta1.deb) 
- [Python 3.x](https://www.python.org/downloads/): Note: When running this quickstart on Windows, it best to install Python from python.org rather than from the Windows store. 
- [Postman](https://www.getpostman.com/) [Optional]

## Step 1 - Setup Dapr 

Follow [instructions](https://docs.dapr.io/getting-started/install-dapr/) to download and install the Dapr CLI and initialize Dapr.

## Step 2 - Understand the code

Now that Dapr is set up locally, clone the repo, then navigate to the Hello World quickstart: 

```sh
git clone [-b <dapr_version_tag>] https://github.com/dapr/quickstarts.git
cd quickstarts/hello-world
```

> **Note**: See https://github.com/dapr/quickstarts#supported-dapr-runtime-version for supported tags. Use `git clone https://github.com/dapr/quickstarts.git` when using the edge version of dapr runtime.


In the `app.bal` you'll find a simple `ballerina` application, which exposes a few routes and handlers. First, take a look at the top of the file: 

```ballerina
string daprPortStr = os:getEnv("DAPR_HTTP_PORT");
string daprPort = daprPortStr is "" ? "3500" : daprPortStr;
const stateStoreName = "statestore";
http:Client clientEP = check new ("http://localhost:" + daprPort + "/v1.0/state/" + stateStoreName);
```

Dapr CLI creates an environment variable for the Dapr port, which defaults to 3500. You'll be using this in step 3 when sending POST messages to the system. The `stateStoreName` is the name given to the state store. You'll come back to that later on to see how that name is configured.

Next, take a look at the ```neworder``` handler:

```ballerina
    resource function post neworder(http:Request req) returns json|error {
        json payload = check req.getJsonPayload();
        json data = check payload.data;
        int orderId = check data.orderId;
        log:printInfo("Got a new order! Order ID: " + orderId.toString());

        json state = [{
            key: "order",
            value: data
        }];
        
        http:Response resp = check clientEP->post("", state);
        if (resp.statusCode == 204) {
            json success = ("Successfully persisted state.");
            return success;
        }
                log:printInfo(resp.statusCode.toString());
        json failure = ("An error occured.");
        return failure;
    }
```

Here the app is exposing an endpoint that will receive and handle `neworder` messages. It first logs the incoming message, and then persist the order ID to the Redis store by posting a state array to the `/state/<state-store-name>` endpoint.

This approach, however, doesn't allow you to verify if the message successfully persisted.

The app also exposes a GET endpoint, `/order`:

```ballerina
    resource function get 'order() returns json|error {
        json payload = check clientEP->get("/order", targetType = json);
        return payload;
    }
```

This calls out to the Redis cache to retrieve the latest value of the "order" key, which effectively allows the Ballerina app to be _stateless_. 

## Step 3 - Run the Ballerina app with Dapr

Run Ballerina app with Dapr: 
   ```bash
   dapr run --app-id balapp --app-port 3000 --dapr-http-port 3500 bal run app.bal
   ```


The command should output text that looks like the following, along with logs:

```
Starting Dapr with id balapp. HTTP Port: 3500. gRPC Port: 9165
You're up and running! Both Dapr and your app logs will appear here.
...
```
> **Note**: the `--app-port` (the port the app runs on) is configurable. The Ballerina app happens to run on port 3000, but you could configure it to run on any other port. Also note that the Dapr `--app-port` parameter is optional, and if not supplied, a random available port is used.

The `dapr run` command looks for the default components directory which for Linux/MacOS is `$HOME/.dapr/components` and for Windows is `%USERPROFILE%\.dapr\components` which holds yaml definition files for components Dapr will be using at runtime. When running locally, the yaml files which provide default definitions for a local development environment are placed in this default components directory. Review the `statestore.yaml` file in the `components` directory:

```yml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: statestore
spec:
  type: state.redis
  version: v1
...
```

You can see the yaml file defined the state store to be Redis and is naming it `statestore`. This is the name which was used in `app.bal` to make the call to the state store in the application: 

```ballerina
const stateStoreName = "statestore";
http:Client clientEP = check new ("http://localhost:" + daprPort + "/v1.0/state/" + stateStoreName);
```

While in this tutorial the default yaml files were used, usually a developer would modify them or create custom yaml definitions depending on the application and scenario.

## Step 4 - Post messages to the service

Now that Dapr and the Ballerina app are running, you can send POST messages against it, using different tools. **Note**: here the POST message is sent to port 3500 - if you used a different port, be sure to update your URL accordingly.

First, POST the message by using Dapr cli in a new command line terminal:

Windows Command Prompt
```sh
dapr invoke --app-id balapp --method neworder --data "{\"data\": { \"orderId\": \"42\" } }"
```

Windows PowerShell
```sh
dapr invoke --app-id balapp --method neworder --data '{\"data\": { \"orderId\": \"42\" } }'
```

Linux or MacOS

```bash
dapr invoke --app-id balapp --method neworder --data '{"data": { "orderId": "42" } }'
```

Alternatively, using `curl`:

```bash
curl -XPOST -d @sample.json -H "Content-Type:application/json" http://localhost:3500/v1.0/invoke/balapp/method/neworder
```

Or, using the Visual Studio Code [Rest Client Plugin](https://marketplace.visualstudio.com/items?itemName=humao.rest-client)

[sample.http](sample.http)
```http
POST http://localhost:3500/v1.0/invoke/balapp/method/neworder

{
  "data": {
    "orderId": "42"
  } 
}
```

Last but not least, you can use the Postman GUI.

Open Postman and create a POST request against `http://localhost:3500/v1.0/invoke/balapp/method/neworder`
![Postman Screenshot](./img/postman1.jpg)
In your terminal window, you should see logs indicating that the message was received and state was updated:
```bash
== APP == Got a new order! Order ID: 42
== APP == Successfully persisted state.
```

## Step 5 - Confirm successful persistence

Now, to verify the order was successfully persisted to the state store, create a GET request against: `http://localhost:3500/v1.0/invoke/balapp/method/order`. **Note**: Again, be sure to reflect the right port if you chose a port other than 3500.

```bash
curl http://localhost:3500/v1.0/invoke/balapp/method/order
```

or use Dapr CLI

```bash
dapr invoke --app-id balapp --method order --verb GET
```

or use the Visual Studio Code [Rest Client Plugin](https://marketplace.visualstudio.com/items?itemName=humao.rest-client)

[sample.http](sample.http)
```http
GET http://localhost:3500/v1.0/invoke/balapp/method/order
```

or use the Postman GUI

![Postman Screenshot 2](./img/postman2.jpg)

This invokes the `/order` route, which calls out to the Redis store for the latest data. Observe the expected result!

## Step 6 - Run the Python app with Dapr

Take a look at the Python App to see how another application can invoke the Ballerina App via Dapr without being aware of the destination's hostname or port. In the `app.py` file you can find the endpoint definition to call the Ballerina App via Dapr.

```python
dapr_port = os.getenv("DAPR_HTTP_PORT", 3500)
dapr_url = "http://localhost:{}/v1.0/invoke/balapp/method/neworder".format(dapr_port)
```
It is important to notice the Ballerina App's name (`balapp`) in the URL, it will allow Dapr to redirect the request to the right API endpoint. This name needs to match the name used to run the Ballerina App earlier in this exercise.

The code block below shows how the Python App will incrementally post a new orderId every second, or print an exception if the post call fails.

```python
n = 0
while True:
    n += 1
    message = {"data": {"orderId": n}}

    try:
        response = requests.post(dapr_url, json=message)
    except Exception as e:
        print(e)

    time.sleep(1)
```

Now open a **new** command line terminal and go to the `hello-world` directory.

1. Install dependencies:

   ```bash
   pip3 install requests
   ```

2. Start the Python App with Dapr: 

   ```bash
   dapr run --app-id pythonapp python3 app.py
   ```

3. If all went well, the **other** terminal, running the Ballerina App, should log entries like these:

    ```
    Got a new order! Order ID: 1
    Successfully persisted state
    Got a new order! Order ID: 2
    Successfully persisted state
    Got a new order! Order ID: 3
    Successfully persisted state
    ```

> **Known Issue**: If you are running python3 on Windows from the Microsoft Store, and you get the following error message:

    exec: "python3": executable file not found in %!P(MISSING)ATH%!(NOVERB)

> This is due to golang being unable to properly execute Microsoft Store aliases. You can use the following command instead of the above:

    dapr run --app-id pythonapp cmd /c "python3 app.py"

> For more info please see [this](https://github.com/dapr/quickstarts/issues/240) issue.

4. Now, perform a GET request a few times and see how the orderId changes every second (enter it into the web browser, use Postman, or curl):

    ```http
    GET http://localhost:3500/v1.0/invoke/balapp/method/order
    ```
    ```json
    {
        "orderId": 3
    }
    ```

> **Note**: It is not required to run `dapr init` in the **second** command line terminal because dapr was already setup on your local machine initially, running this command again would fail.

## Step 7 - Cleanup

To stop your services from running, simply stop the "dapr run" process. Alternatively, you can spin down each of your services with the Dapr CLI "stop" command. For example, to spin down both services, run these commands in a new command line terminal: 

```bash
dapr stop --app-id balapp
dapr stop --app-id pythonapp
```

To see that services have stopped running, run `dapr list`, noting that your services no longer appears!

## Next steps

Now that you've gotten Dapr running locally on your machine, consider these next steps:
- Explore additional quickstarts such as [pub-sub](../pub-sub), [bindings](../bindings) or the [distributed calculator app](../distributed-calculator).
- Run this hello world application in Kubernetes via the [Hello Kubernetes](../hello-kubernetes) quickstart.
- Learn more about Dapr in the [Dapr overview](https://docs.dapr.io/concepts/overview/) documentation.
- Explore [Dapr concepts](https://docs.dapr.io/concepts/) such as building blocks and components in the Dapr documentation.
