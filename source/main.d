import std.stdio;
import std.socket;
import std.process;
import std.parallelism;
import std.file;
import std.array;
import std.conv;
import std.string;

import core.thread;

struct Request
{
    enum Type { GET, POST }
    
    Type type;
    string request; 
}

Request request_parser(string request)
{
    auto request_lines = splitLines(request);
    auto split_request = split(request_lines[0]);

    Request req;
    req.request = split_request[1];

    if(split_request[0] == "GET")
    {
        req.type = Request.Type.GET;
    }
    
    return req;
}

class Cache
{
    
}

struct Config
{
    string request;
    string filename;
}

class ConfigStore
{
public:
    
    this(string filename)
    {
        auto file = File(filename);
        
        foreach(line ; file.byLine())
        {
            auto split_line = split(line); 
            assert(split_line.length == 2);
            
            Config c;
            c.request = to!string(split_line[0]);
            c.filename = to!string(split_line[1]);
            
            m_config_store[c.request] = c;
        }
    }
    
    Config get(string request) const
    {
        return m_config_store[request];
    }
    
private:
    Config[string] m_config_store;
}

class Router
{
    this()
    {
        
    }
}

void handle_request(Socket client, ConfigStore config)
{
    char[256] buffer;
    
    const long received = client.receive(buffer);
    if(received == Socket.ERROR)
    {
        client.send("HTTP/1.0 500 Internal Server Error\n\nHTTP/1.0 500 Internal Server Error");
        client.shutdown(SocketShutdown.BOTH);
        client.close();  
        
        return;
    }
    
    Request request = request_parser(to!string(buffer));
    
    Config conf = config.get(request.request);

    string data = readText("/home/olafurw/workspace/server/data/" ~ conf.filename);
    
    client.send("HTTP/1.0 200 OK\n\n" ~ data);
    client.shutdown(SocketShutdown.BOTH);
    client.close();  
}

class Listener : Thread
{
    this()
    {
        super(&run);
    }

    Socket m_server;
    ConfigStore m_config;

    void run()
    {
        m_config = new ConfigStore("/home/olafurw/workspace/server/data/config");
        
        m_server = new TcpSocket();
        m_server.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
        m_server.bind(new InternetAddress(8080));
        m_server.listen(1);

        while(true)
        {
            Socket client = m_server.accept();
            
            auto request_task = task(&handle_request, client, m_config);
            taskPool.put(request_task);
        }
    }
}

void main()
{
    Listener l = new Listener();
    l.start();
}