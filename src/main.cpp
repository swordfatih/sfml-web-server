#include <iostream>
#include "App.h"
#include "LocalCluster.h"
#include <memory>
#include <SFML/Graphics.hpp>
#include <vector>
#include <mutex>
#include <thread>
#include <optional>

struct Context {
    sf::RenderWindow window;
    std::vector<uint8_t> image;      // latest PNG bytes
    std::mutex imageMutex;           // protects image
};

std::vector<uint8_t> screenshot(sf::RenderWindow& window) {
    sf::Texture texture({200, 200});
    texture.update(window);
    sf::Image image = texture.copyToImage();
    return image.saveToMemory("png").value(); // SFML 3
}

void render_loop(std::shared_ptr<Context> context) {
    context->window.setActive(true);

    sf::CircleShape shape(10.f);
    shape.setFillColor(sf::Color::Green);

    while (context->window.isOpen()) {
        while (const std::optional event = context->window.pollEvent()) {
            if (event->is<sf::Event::Closed>())
                context->window.close();
        }

        context->window.clear();
        context->window.draw(shape);
        context->window.display();

        if(shape.getPosition().x < 300) {
            shape.move({1, 0});
        } else {
            shape.setPosition({0, 0});
        }

        auto bytes = screenshot(context->window);
        context->image = std::move(bytes);

        // optional: limit FPS so you don't burn CPU
        std::this_thread::sleep_for(std::chrono::milliseconds(33)); // ~30fps
    }
}

int main() {
    auto context = std::make_shared<Context>();
    context->window.create(sf::VideoMode({200, 200}), "SFML works!");
    context->window.setFramerateLimit(60);
    context->window.setActive(false);

    std::thread t(render_loop, context);

    uWS::LocalCluster({
        .key_file_name  = "key.pem",
        .cert_file_name = "cert.pem",
        .passphrase     = "1234"
    }, [context](uWS::SSLApp &app) {

        // Live page
        app.get("/", [](auto *res, auto *) {
            // Simple auto-refreshing HTML. Cache-bust with ?t=...
            const char *html =
                "<!doctype html><html><head><meta charset='utf-8'/>"
                "<title>Live Frame</title>"
                "<style>body{margin:0;display:grid;place-items:center;height:100vh;background:#111}"
                "img{image-rendering:pixelated;border:1px solid #333}</style>"
                "</head><body>"
                "<img id='f' width='400' height='400'/>"
                "<script>"
                "const img=document.getElementById('f');"
                "function tick(){ img.src='/frame.png?t='+Date.now(); }"
                "setInterval(tick, 100); tick();"
                "</script>"
                "</body></html>";

            res->writeHeader("Content-Type", "text/html; charset=utf-8");
            res->end(html);
        });

        // Frame endpoint
        app.get("/frame.png", [context](auto *res, auto *) {
            std::vector<uint8_t> copy;
            {
                std::lock_guard lock(context->imageMutex);
                copy = context->image; // copy while locked, then unlock
            }

            if (copy.empty()) {
                res->writeStatus("503 Service Unavailable")->end("No frame yet");
                return;
            }

            res->writeHeader("Content-Type", "image/png");
            res->writeHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
            res->writeHeader("Pragma", "no-cache");

            // keep buffer alive through end()
            auto payload = std::make_shared<std::vector<uint8_t>>(std::move(copy));
            res->end(std::string_view(
                reinterpret_cast<const char*>(payload->data()),
                payload->size()
            ));
        });

        app.listen(3000, [](auto *listen_socket) {
            if (listen_socket) {
                std::cout << "HTTPS live view: https://127.0.0.1:3000/\n";
            } else {
                std::cout << "Failed to listen on 3000\n";
            }
        });
    });

    t.join();
    return 0;
}
