/**
 *  @file
 *  @copyright defined in eos/LICENSE
 */
#pragma once
#include <appbase/application.hpp>
#include <fc/exception/exception.hpp>

#include <fc/reflect/reflect.hpp>

#include <boost/asio.hpp>

#include <websocketpp/config/asio_client.hpp>
#include <websocketpp/config/asio.hpp>
#include <websocketpp/server.hpp>
#include <websocketpp/config/asio_client.hpp>
#include <websocketpp/client.hpp>
#include <websocketpp/logger/stub.hpp>

namespace eosio {
   using namespace appbase;
   using std::unordered_map;

   /**
    * @brief A callback function provided to a URL handler to
    * allow it to specify the HTTP response code and body
    *
    * Arguments: response_code, response_body
    */
   using url_response_callback = std::function<void(int,string)>;

   /**
    * @brief Callback type for a URL handler
    *
    * URL handlers have this type
    *
    * The handler must guarantee that url_response_callback() is called;
    * otherwise, the connection will hang and result in a memory leak.
    *
    * Arguments: url, request_body, response_callback
    **/
   using url_handler = std::function<void(string,string,url_response_callback)>;

   /**
    * @brief An API, containing URLs and handlers
    *
    * An API is composed of several calls, where each call has a URL and
    * a handler. The URL is the path on the web server that triggers the
    * call, and the handler is the function which implements the API call
    */
   using api_description = std::map<string, url_handler>;

   struct http_plugin_defaults {
      //If not empty, this string is prepended on to the various configuration
      // items for setting listen addresses
      string address_config_prefix;
      //If empty, unix socket support will be completely disabled. If not empty,
      // unix socket support is enabled with the given default path (treated relative
      // to the datadir)
      string default_unix_socket_path;
      //If non 0, HTTP will be enabled by default on the given port number. If
      // 0, HTTP will not be enabled by default
      uint16_t default_http_port{0};
   };

   /**
    * @brief Internal websocketpp socket config structure
    */
   namespace http_config {
      namespace asio = boost::asio;

      template<typename SocketType>
      struct asio_with_stub_log : public websocketpp::config::asio {
         typedef asio_with_stub_log type;
         typedef asio base;

         typedef base::concurrency_type concurrency_type;

         typedef base::request_type request_type;
         typedef base::response_type response_type;

         typedef base::message_type message_type;
         typedef base::con_msg_manager_type con_msg_manager_type;
         typedef base::endpoint_msg_manager_type endpoint_msg_manager_type;

         typedef websocketpp::log::stub elog_type;
         typedef websocketpp::log::stub alog_type;

         typedef base::rng_type rng_type;

         struct transport_config : public base::transport_config {
            typedef type::concurrency_type concurrency_type;
            typedef type::alog_type alog_type;
            typedef type::elog_type elog_type;
            typedef type::request_type request_type;
            typedef type::response_type response_type;
            typedef SocketType socket_type;
         };

         typedef websocketpp::transport::asio::endpoint<transport_config> transport_type;
      };
   }

   /**
    * @brief WebSocket connection type (shared pointer)
    */
   template<typename SocketType>
   using ws_connection = typename websocketpp::server<eosio::http_config::asio_with_stub_log<SocketType>>::connection_ptr;

   /**
    * @brief WebSocket message type (shared pointer)
    */
   template<typename SocketType>
   using ws_message = typename websocketpp::server<eosio::http_config::asio_with_stub_log<SocketType>>::message_ptr;

   /**
    * @brief Callback type for a WebSocket message handler
    *
    * Arguments: ws_connection, ws_message
    */
   template<typename SocketType>
   using ws_message_handler = std::function<void(ws_connection<SocketType>, ws_message<SocketType>)>;

   /**
    * @brief Callback type called after websocket connection is terminated
    *
    * Arguments: ws_connection
    */
   template<typename SocketType>
   using ws_connection_termination_handler = std::function<void(ws_connection<SocketType>)>;

   /**
    * @brief Internal websocketpp connection type
    */
   using basic_socket_endpoint = websocketpp::transport::asio::basic_socket::endpoint;

   /**
    * @brief Internal websocketpp connection type for TLS
    */
   using tls_socket_endpoint = websocketpp::transport::asio::tls_socket::endpoint;

   /**
    * @brief Equality function of ws_connection
    */
   template<typename SocketType>
   struct ws_connection_equal {
      bool operator()(const ws_connection<SocketType> &lhs, const ws_connection<SocketType> &rhs) const {
         return lhs.get() == rhs.get();
      }
   };

   /**
    * @brief Hash function of ws_connection
    */
   template<typename SocketType>
   struct ws_connection_hash {
      size_t operator()(const ws_connection<SocketType> &conn) const {
         return reinterpret_cast<size_t>(conn.get());
      }
   };

   /**
    *  This plugin starts an HTTP server and dispatches queries to
    *  registered handles based upon URL. The handler is passed the
    *  URL that was requested and a callback method that should be
    *  called with the response code and body.
    *
    *  The handler will be called from the appbase application io_service
    *  thread.  The callback can be called from any thread and will
    *  automatically propagate the call to the http thread.
    *
    *  The HTTP service will run in its own thread with its own io_service to
    *  make sure that HTTP request processing does not interfere with other
    *  plugins.
    */
   class http_plugin : public appbase::plugin<http_plugin>
   {
      public:
        http_plugin();
        virtual ~http_plugin();

        //must be called before initialize
        static void set_defaults(const http_plugin_defaults config);

        APPBASE_PLUGIN_REQUIRES()
        virtual void set_program_options(options_description&, options_description& cfg) override;

        void plugin_initialize(const variables_map& options);
        void plugin_startup();
        void plugin_shutdown();

        void add_handler(const string& url, const url_handler&);
        void add_api(const api_description& api) {
           for (const auto& call : api)
              add_handler(call.first, call.second);
        }

        // standard exception handling for api handlers
        static void handle_exception( const char *api_name, const char *call_name, const string& body, url_response_callback cb );

        bool is_on_loopback() const;
        bool is_secure() const;

        void add_ws_handler(const string& url, ws_message_handler<basic_socket_endpoint> handler);
        void add_wss_handler(const string& url, ws_message_handler<tls_socket_endpoint> handler);
        void set_ws_connection_termination_handler(ws_connection_termination_handler<basic_socket_endpoint> handler);
        void set_wss_connection_termination_handler(ws_connection_termination_handler<tls_socket_endpoint> handler);

        bool verbose_errors()const;

      private:
        std::unique_ptr<class http_plugin_impl> my;
   };

   /**
    * @brief Structure used to create JSON error responses
    */
   struct error_results {
      uint16_t code;
      string message;

      struct error_info {
         int64_t code;
         string name;
         string what;

         struct error_detail {
            string message;
            string file;
            uint64_t line_number;
            string method;
         };

         vector<error_detail> details;

         static const uint8_t details_limit = 10;

         error_info() {};

         error_info(const fc::exception& exc, bool include_all_log) {
            code = exc.code();
            name = exc.name();
            what = exc.what();
            for (auto itr = exc.get_log().begin(); itr != exc.get_log().end(); ++itr) {
               // Prevent sending trace that are too big
               // Append error
               error_detail detail = {
                     itr->get_message(), itr->get_context().get_file(),
                     itr->get_context().get_line_number(), itr->get_context().get_method()
               };
               details.emplace_back(detail);

               if (!include_all_log) break;
               if (details.size() >= details_limit) break;
           }
         }
      };

      error_info error;
   };
}

FC_REFLECT(eosio::error_results::error_info::error_detail, (message)(file)(line_number)(method))
FC_REFLECT(eosio::error_results::error_info, (code)(name)(what)(details))
FC_REFLECT(eosio::error_results, (code)(message)(error))
