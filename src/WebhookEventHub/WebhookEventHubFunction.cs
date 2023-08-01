using Azure.Messaging.EventHubs;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using System;
using System.IO;
using System.Threading.Tasks;
using System.Web.Http;

namespace WebhookEventHub
{
    public static class WebhookEventHubFunction
    {
        [FunctionName(nameof(WebhookEventHubFunction))]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req,
            [EventHub("%EventHubName%", Connection = "EventHubConnection")] IAsyncCollector<EventData> outputEvents,
            ILogger log)
        {
            try
            {
                log.LogInformation("WebhookEventHubFunction processed a request.");

                string name = req.Query["name"];

                string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
                dynamic data = JsonConvert.DeserializeObject(requestBody);

                name = name ?? data?.name;
                if (string.IsNullOrEmpty(name))
                    name = "unknown";

                name = name.Substring(0, Math.Min(name.Length, 20));

                log.LogInformation("WebhookEventHubFunction parameter 'name' value is {name}.", name);

                // If your scenario requires that certain events are grouped together in an
                // Event Hubs partition, you can specify a partition key.  Events added with 
                // the same key will always be assigned to the same partition.        
                await outputEvents.AddAsync(new EventData($"New Event - {name}"), "my-events-key");

                return new OkObjectResult($"New Event created for name: {name}.");
            }
            catch (Exception ex)
            {
                log.LogError("WebhookEventHubFunction Error", ex);
                return new ExceptionResult(ex, includeErrorDetail: true);
            }
        }
    }
}
