using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Producer;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;



if (!int.TryParse(args[0], out var numberOfEventsPerSecond))
{
    PrintUsage();
    return;
}

if (!int.TryParse(args[1], out var seconds))
{
    PrintUsage();
    return;
}

var c = new ConfigurationBuilder()
    .AddUserSecrets<EventHubConfiguration>()
    .AddJsonFile("appsettings.json", true)
    .Build()
    .GetSection(nameof(EventHubConfiguration))
    .Get<EventHubConfiguration>();

await using var client = new EventHubProducerClient(c.ConnectionString, c.EventHubName);

var index = 0;
var tasks = new List<Task>();
while (true)
{
    var iteration = index++;
    Console.WriteLine($"Iteration {iteration} started.");
    tasks.Add(Task.Run(async () =>
    {
        var events = await client.CreateBatchAsync();
        foreach (var i in Enumerable.Range(0, numberOfEventsPerSecond))
        {
            events.TryAdd(new EventData(CreateJson(iteration * numberOfEventsPerSecond + i)));
        }

        await client.SendAsync(events);
        Console.WriteLine($"Iteration {iteration} ended. ({events.Count} events.)");
    }));

    if (index >= seconds) { break; }

    await Task.Delay(1000);
}

Console.WriteLine("全ての処理の完了待ち.");
await Task.WhenAll(tasks);
Console.WriteLine($"{numberOfEventsPerSecond * seconds} 件のイベントを送信しました。.");


void PrintUsage()
{
    Console.WriteLine("EventHubMessageSender totalEventCount seconds");
    Console.WriteLine("Usage: EventHubMessageSender 1000000 3600");
}

byte[] CreateJson(int termNo)
{
    return Encoding.UTF8.GetBytes($@"
{{
    ""term_no"": ""{termNo}"",
    ""sokui_time"": ""20210307083519"",
    ""latitude"": ""35.732351"",
    ""longtitude"": ""139.686683""
}}");

}

class EventHubConfiguration
{
    public string ConnectionString { get; set; }
    public string EventHubName { get; set; }
}

