#include <utility>

/**
 *  @file
 *  @copyright defined in eos/LICENSE.txt
 */
#include <eosio/http_plugin/http_plugin.hpp>
#include <eosio/http_plugin/local_endpoint.hpp>
#include <eosio/chain/exceptions.hpp>

#include <fc/network/ip.hpp>
#include <fc/log/logger_config.hpp>
#include <fc/reflect/variant.hpp>
#include <fc/io/json.hpp>
#include <fc/crypto/openssl.hpp>

#include <boost/optional.hpp>

#include <thread>
#include <memory>
#include <regex>

namespace eosio {

   static appbase::abstract_plugin& _http_plugin = app().register_plugin<http_plugin>();

   namespace asio = boost::asio;

   using std::unordered_map;
   using std::vector;
   using std::unordered_set;
   using std::string;
   using std::regex;
   using boost::optional;
   using boost::asio::ip::tcp;
   using boost::asio::ip::address_v4;
   using boost::asio::ip::address_v6;
   using std::shared_ptr;
   using websocketpp::connection_hdl;
   using namespace websocketpp::close;
   using local_socket_endpoint = asio::local::stream_protocol::endpoint;

   static http_plugin_defaults current_http_plugin_defaults;

   void http_plugin::set_defaults(const http_plugin_defaults config) {
      current_http_plugin_defaults = config;
   }

   namespace http_config {
       struct asio_local_with_stub_log : public websocketpp::config::asio {
           typedef asio_local_with_stub_log type;
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
               typedef websocketpp::transport::asio::basic_socket::local_endpoint socket_type;
           };

           typedef websocketpp::transport::asio::local_endpoint<transport_config> transport_type;
       };
   }

   using websocket_server_type = websocketpp::server<http_config::asio_with_stub_log<basic_socket_endpoint>>;
   using websocket_server_tls_type = websocketpp::server<http_config::asio_with_stub_log<tls_socket_endpoint>>;
   using websocket_local_server_type = websocketpp::server<http_config::asio_local_with_stub_log>;
   using ssl_context_ptr = websocketpp::lib::shared_ptr<websocketpp::lib::asio::ssl::context>;

#define DEFINE_ENABLE_IF_TEMPLATE_GETTERS(first, second, getter_name)                                       \
   template<typename SocketType>                                                                            \
   typename std::enable_if<std::is_same<SocketType, basic_socket_endpoint>::value, decltype(first) &>::type \
   getter_name() {                                                                                          \
      return first;                                                                                         \
   }                                                                                                        \
                                                                                                            \
   template<typename SocketType>                                                                            \
   typename std::enable_if<std::is_same<SocketType, tls_socket_endpoint>::value, decltype(second) &>::type  \
   getter_name() {                                                                                          \
      return second;                                                                                        \
   }                                                                                                        \


   static bool verbose_http_errors = false;

   class http_plugin_impl {
      template<typename SocketType>
      struct ws_connection_equal {
         bool operator()(const ws_connection<SocketType> &lhs, const ws_connection<SocketType> &rhs) const {
            return lhs.get() == rhs.get();
         }
      };

      template<typename SocketType>
      struct ws_connection_hash {
         size_t operator()(const ws_connection<SocketType> &conn) const {
            return reinterpret_cast<size_t>(conn.get());
         }
      };

      template<typename SocketType>
      using ws_connection_to_message_handler_map =
              std::unordered_map<ws_connection<SocketType>, ws_message_handler<SocketType>,
                                 ws_connection_hash<SocketType>, ws_connection_equal<SocketType>>;

      public:
         unordered_map<string, ws_message_handler<basic_socket_endpoint>> ws_message_handlers;
         unordered_map<string, ws_message_handler<tls_socket_endpoint>> wss_message_handlers;
         DEFINE_ENABLE_IF_TEMPLATE_GETTERS(ws_message_handlers, wss_message_handlers, get_websocket_msghandler_map);

         ws_connection_to_message_handler_map<basic_socket_endpoint> ws_connection_to_msgh_map;
         ws_connection_to_message_handler_map<tls_socket_endpoint> wss_connection_to_msgh_map;
         DEFINE_ENABLE_IF_TEMPLATE_GETTERS(ws_connection_to_msgh_map, wss_connection_to_msgh_map, get_ws_connection_to_msghandler_map);

         ws_connection_termination_handler<basic_socket_endpoint> plain_ws_connection_term_handler;
         ws_connection_termination_handler<tls_socket_endpoint> tls_ws_connection_term_handler;
         DEFINE_ENABLE_IF_TEMPLATE_GETTERS(plain_ws_connection_term_handler, tls_ws_connection_term_handler, get_ws_connection_termination_handler);

         unordered_map<string, url_handler> url_handlers;
         optional<tcp::endpoint>  listen_endpoint;
         string                   access_control_allow_origin;
         string                   access_control_allow_headers;
         string                   access_control_max_age;
         bool                     access_control_allow_credentials = false;
         size_t                   max_body_size;

         websocket_server_type    server;

         optional<tcp::endpoint>  https_listen_endpoint;
         string                   https_cert_chain;
         string                   https_key;

         websocket_server_tls_type https_server;

         optional<local_socket_endpoint> unix_endpoint;
         websocket_local_server_type unix_server;

         bool                     validate_host;
         unordered_set<string>    valid_hosts;

         unordered_set<ws_connection<basic_socket_endpoint>> http_connections;
         unordered_set<ws_connection<tls_socket_endpoint>> https_connections;
         DEFINE_ENABLE_IF_TEMPLATE_GETTERS(http_connections, https_connections, get_connection_set);

         /* just for compile purpose */
         unordered_set<websocketpp::server<http_config::asio_local_with_stub_log>::connection_ptr> local_connections;
         template<typename SocketType>
         typename std::enable_if<std::is_same<SocketType, local_socket_endpoint>::value, decltype(local_connections) &>::type
         get_connection_set() {
            return local_connections;
         }

         uint32_t                 idle_connection_timeout_ms;
         uint32_t                 max_connections;

         bool is_max_connections_reached() {
            return max_connections > 0 &&
                   (http_connections.size() + https_connections.size() + ws_connection_to_msgh_map.size() + wss_connection_to_msgh_map.size())
                    >= max_connections;
         }

         template <typename HttpConfigType, typename SocketType>
         bool is_already_connected(typename websocketpp::server<HttpConfigType>::connection_ptr ws_conn) {
            if (std::is_same<SocketType, local_socket_endpoint>::value) return true;
            if (max_connections == 0) return true;

            auto &connection_set = get_connection_set<SocketType>();
            return connection_set.find(ws_conn) != connection_set.end();
         }

         template <typename HttpConfigType, typename SocketType>
         void register_keep_alive_http_connection(typename websocketpp::server<HttpConfigType>::connection_ptr ws_conn) {
            if (std::is_same<SocketType, local_socket_endpoint>::value) return;
            if (max_connections == 0) return;

            auto &connection_set = get_connection_set<SocketType>();
            connection_set.insert(ws_conn);
         }

         template <typename HttpConfigType, typename SocketType>
         void unregister_keep_alive_http_connection(typename websocketpp::server<HttpConfigType>::connection_ptr ws_conn) {
            if (std::is_same<SocketType, local_socket_endpoint>::value) return;
            if (max_connections == 0) return;

            auto &connection_set = get_connection_set<SocketType>();
            connection_set.erase(ws_conn);
         }

         string                   unix_socket_path_option_name     = "unix-socket-path";
         string                   http_server_address_option_name  = "http-server-address";
         string                   https_server_address_option_name = "https-server-address";

         bool host_port_is_valid( const std::string& header_host_port, const string& endpoint_local_host_port ) {
            return !validate_host || header_host_port == endpoint_local_host_port || valid_hosts.find(header_host_port) != valid_hosts.end();
         }

         bool host_is_valid( const std::string& host, const string& endpoint_local_host_port, bool secure) {
            if (!validate_host) {
               return true;
            }

            // normalise the incoming host so that it always has the explicit port
            static auto has_port_expr = regex("[^:]:[0-9]+$"); /// ends in :<number> without a preceeding colon which implies ipv6
            if (std::regex_search(host, has_port_expr)) {
               return host_port_is_valid( host, endpoint_local_host_port );
            } else {
               // according to RFC 2732 ipv6 addresses should always be enclosed with brackets so we shouldn't need to special case here
               return host_port_is_valid( host + ":" + std::to_string(secure ? websocketpp::uri_default_secure_port : websocketpp::uri_default_port ), endpoint_local_host_port);
            }
         }

         ssl_context_ptr on_tls_init(const websocketpp::connection_hdl &hdl) {
            ssl_context_ptr ctx = websocketpp::lib::make_shared<websocketpp::lib::asio::ssl::context>(asio::ssl::context::sslv23_server);

            try {
               ctx->set_options(asio::ssl::context::default_workarounds |
                                asio::ssl::context::no_sslv2 |
                                asio::ssl::context::no_sslv3 |
                                asio::ssl::context::no_tlsv1 |
                                asio::ssl::context::no_tlsv1_1 |
                                asio::ssl::context::single_dh_use);

               ctx->use_certificate_chain_file(https_cert_chain);
               ctx->use_private_key_file(https_key, asio::ssl::context::pem);

               //going for the A+! Do a few more things on the native context to get ECDH in use

               fc::ec_key ecdh = EC_KEY_new_by_curve_name(NID_secp384r1);
               if (!ecdh)
                  EOS_THROW(chain::http_exception, "Failed to set NID_secp384r1");
               if(SSL_CTX_set_tmp_ecdh(ctx->native_handle(), (EC_KEY*)ecdh) != 1)
                  EOS_THROW(chain::http_exception, "Failed to set ECDH PFS");

               if(SSL_CTX_set_cipher_list(ctx->native_handle(), \
                  "EECDH+ECDSA+AESGCM:EECDH+aRSA+AESGCM:EECDH+ECDSA+SHA384:EECDH+ECDSA+SHA256:AES256:" \
                  "!DHE:!RSA:!AES128:!RC4:!DES:!3DES:!DSS:!SRP:!PSK:!EXP:!MD5:!LOW:!aNULL:!eNULL") != 1)
                  EOS_THROW(chain::http_exception, "Failed to set HTTPS cipher list");
            } catch (const fc::exception& e) {
               elog("https server initialization error: ${w}", ("w", e.to_detail_string()));
               throw;
            } catch(std::exception& e) {
               elog("https server initialization error: ${w}", ("w", e.what()));
               throw;
            }

            return ctx;
         }

         template<class HttpConfigType>
         static void handle_exception(typename websocketpp::server<HttpConfigType>::connection_ptr con) {
            string err = "Internal Service error, http: ";
            try {
               con->set_status( websocketpp::http::status_code::internal_server_error );
               try {
                  throw;
               } catch (const fc::exception& e) {
                  err += e.to_detail_string();
                  elog( "${e}", ("e", err));
                  error_results results{websocketpp::http::status_code::internal_server_error,
                                        "Internal Service Error", error_results::error_info(e, verbose_http_errors )};
                  con->set_body( fc::json::to_string( results ));
               } catch (const std::exception& e) {
                  err += e.what();
                  elog( "${e}", ("e", err));
                  error_results results{websocketpp::http::status_code::internal_server_error,
                                        "Internal Service Error", error_results::error_info(fc::exception( FC_LOG_MESSAGE( error, e.what())), verbose_http_errors )};
                  con->set_body( fc::json::to_string( results ));
               } catch (...) {
                  err += "Unknown Exception";
                  error_results results{websocketpp::http::status_code::internal_server_error,
                                        "Internal Service Error",
                                        error_results::error_info(fc::exception( FC_LOG_MESSAGE( error, "Unknown Exception" )), verbose_http_errors )};
                  con->set_body( fc::json::to_string( results ));
               }
            } catch (...) {
               con->set_body( R"xxx({"message": "Internal Server Error"})xxx" );
               std::cerr << "Exception attempting to handle exception: " << err << std::endl;
            }
         }

         template<class HttpConfigType>
         bool allow_host(const typename HttpConfigType::request_type& req, typename websocketpp::server<HttpConfigType>::connection_ptr con) {
            bool is_secure = con->get_uri()->get_secure();
            const auto& local_endpoint = con->get_socket().lowest_layer().local_endpoint();
            auto local_socket_host_port = local_endpoint.address().to_string() + ":" + std::to_string(local_endpoint.port());

            const auto& host_str = req.get_header("Host");
            if (host_str.empty() || !host_is_valid(host_str, local_socket_host_port, is_secure)) {
               con->set_status(websocketpp::http::status_code::bad_request);
               return false;
            }
            return true;
         }

         template<class T, class SocketType> // T == HttpConfigType
         void handle_http_request(typename websocketpp::server<T>::connection_ptr con) {
            try {
               bool is_already_keep_alive = is_already_connected<T, SocketType>(con);
               if (!is_already_keep_alive && is_max_connections_reached()) {
                  con->set_status(websocketpp::http::status_code::too_many_requests);
                  return;
               }

               auto& req = con->get_request();

               if(!allow_host<T>(req, con))
                  return;

               if( !access_control_allow_origin.empty()) {
                  con->append_header( "Access-Control-Allow-Origin", access_control_allow_origin );
               }
               if( !access_control_allow_headers.empty()) {
                  con->append_header( "Access-Control-Allow-Headers", access_control_allow_headers );
               }
               if( !access_control_max_age.empty()) {
                  con->append_header( "Access-Control-Max-Age", access_control_max_age );
               }
               if( access_control_allow_credentials ) {
                  con->append_header( "Access-Control-Allow-Credentials", "true" );
               }

               if (!is_already_keep_alive) {
                  register_keep_alive_http_connection<T, SocketType>(con);
               }

               if(req.get_method() == "OPTIONS") {
                  con->set_status(websocketpp::http::status_code::ok);
                  return;
               }

               con->append_header( "Content-type", "application/json" );
               auto body = con->get_request_body();
               auto resource = con->get_resource();
               auto handler_itr = url_handlers.find( resource );
               if( handler_itr != url_handlers.end()) {
                  con->defer_http_response();
                  handler_itr->second( resource, body, [con]( auto code, auto&& body ) {
                     con->set_body( std::move( body ));
                     con->set_status( websocketpp::http::status_code::value( code ));
                     con->send_http_response();
                  } );

               } else {
                  error_results results{websocketpp::http::status_code::not_found,
                                        "Not Found", error_results::error_info(fc::exception( FC_LOG_MESSAGE( error, "Unknown Endpoint" )), verbose_http_errors )};
                  con->set_body( fc::json::to_string( results ));
                  con->set_status( websocketpp::http::status_code::not_found );
               }
            } catch( ... ) {
               handle_exception<T>( con );
            }
         }

         template<typename HttpConfigType, typename T>
         void handle_websocket_open(ws_connection<T> conn) {
            auto resource = conn->get_resource();

            auto handler_map = get_websocket_msghandler_map<T>();
            auto handler_itr = handler_map.find(resource);
            if (handler_itr != handler_map.end()) {
               bool is_connected = is_already_connected<HttpConfigType, T>(conn);
               if (!is_connected && is_max_connections_reached()) {
                  error_results results{websocketpp::http::status_code::too_many_requests,
                                        "Too many connections",
                                        error_results::error_info(fc::exception(FC_LOG_MESSAGE(error, "Too many connections")),
                                                                  verbose_http_errors)};
                  conn->close(status::internal_endpoint_error, fc::json::to_string(results));
                  return;
               }

               auto &conn_to_handler_map = get_ws_connection_to_msghandler_map<T>();
               conn_to_handler_map.insert(std::make_pair(conn, handler_itr->second));
            } else {
               error_results results{websocketpp::http::status_code::not_found,
                                     "Not Found",
                                     error_results::error_info(fc::exception(FC_LOG_MESSAGE(error, "Unknown Endpoint")),
                                                               verbose_http_errors)};
               conn->close(status::internal_endpoint_error, fc::json::to_string(results));
            }
         }

         template<typename HttpConfigType, typename T>
         void handle_websocket_close_or_fail(ws_connection<T> conn) {
            if (conn->is_http_connection()) {
               unregister_keep_alive_http_connection<HttpConfigType, T>(conn);
            } else {
               auto &conn_to_handler_map = get_ws_connection_to_msghandler_map<T>();
               conn_to_handler_map.erase(conn);

               auto &term_handler = get_ws_connection_termination_handler<T>();
               if (term_handler) {
                  term_handler(conn);
               }
            }
         }

         template<typename T>
         void handle_websocket_message(ws_connection<T> conn, ws_message<T> msg) {
            //dlog("websocket message handler called for ${h} with ${uri}", ("h", conn->get_host())("uri", conn->get_resource()));

            auto &conn_to_handler_map = get_ws_connection_to_msghandler_map<T>();
            try {
               auto handler_itr = conn_to_handler_map.find(conn);
               if (handler_itr != conn_to_handler_map.end()) {
                  handler_itr->second(conn, msg);
               }
            } catch (const fc::exception& e) {
               auto err = e.to_detail_string();
               elog("${e}", ("e", err));
               conn->close(status::internal_endpoint_error, err);
            } catch (const std::exception &e) {
               elog("${e}", ("e", e.what()));
               conn->close(status::internal_endpoint_error, e.what());
            } catch (...) {
               elog("${e}", ("e", "Unknown error"));
               conn->close(status::internal_endpoint_error, "Unknown error");
            }
         }

         template<class T>
         void create_server_for_endpoint(const tcp::endpoint& ep, websocketpp::server<http_config::asio_with_stub_log<T>>& ws) {
            ws.clear_access_channels(websocketpp::log::alevel::all);
            ws.init_asio(&app().get_io_service());
            ws.set_reuse_addr(true);
            ws.set_max_http_body_size(max_body_size);
            ws.set_open_handshake_timeout(idle_connection_timeout_ms);
            ws.set_http_handler([&](connection_hdl hdl) {
               handle_http_request<http_config::asio_with_stub_log<T>, T>(ws.get_con_from_hdl(hdl));
            });
            ws.set_open_handler([&](connection_hdl hdl) {
               handle_websocket_open<http_config::asio_with_stub_log<T>, T>(ws.get_con_from_hdl(hdl));
            });
            ws.set_close_handler([&](connection_hdl hdl) {
               handle_websocket_close_or_fail<http_config::asio_with_stub_log<T>, T>(ws.get_con_from_hdl(hdl));
            });
            ws.set_fail_handler([&](connection_hdl hdl) {
               handle_websocket_close_or_fail<http_config::asio_with_stub_log<T>, T>(ws.get_con_from_hdl(hdl));
            });
            ws.set_message_handler([&](connection_hdl hdl, ws_message<T> msg) {
               handle_websocket_message<T>(ws.get_con_from_hdl(hdl), msg);
            });
         }

         void add_aliases_for_endpoint( const tcp::endpoint& ep, const string &host, const string &port ) {
            auto resolved_port_str = std::to_string(ep.port());
            valid_hosts.emplace(host + ":" + port);
            valid_hosts.emplace(host + ":" + resolved_port_str);
         }

         void mangle_option_names() {
            if(current_http_plugin_defaults.address_config_prefix.empty())
               return;
            unix_socket_path_option_name.insert(0, current_http_plugin_defaults.address_config_prefix+"-");
            http_server_address_option_name.insert(0, current_http_plugin_defaults.address_config_prefix+"-");
            https_server_address_option_name.insert(0, current_http_plugin_defaults.address_config_prefix+"-");
         }
   };

   template<>
   bool http_plugin_impl::allow_host<http_config::asio_local_with_stub_log>(
           const http_config::asio_local_with_stub_log::request_type& req,
           websocketpp::server<http_config::asio_local_with_stub_log>::connection_ptr con) {
      return true;
   }

   http_plugin::http_plugin():my(new http_plugin_impl()){}
   http_plugin::~http_plugin(){}

   void http_plugin::set_program_options(options_description&, options_description& cfg) {
      my->mangle_option_names();
      if(current_http_plugin_defaults.default_unix_socket_path.length())
         cfg.add_options()
            (my->unix_socket_path_option_name.c_str(), bpo::value<string>()->default_value(current_http_plugin_defaults.default_unix_socket_path),
             "The filename (relative to data-dir) to create a unix socket for HTTP RPC; set blank to disable.");

      if(current_http_plugin_defaults.default_http_port)
         cfg.add_options()
            (my->http_server_address_option_name.c_str(), bpo::value<string>()->default_value("127.0.0.1:" + std::to_string(current_http_plugin_defaults.default_http_port)),
             "The local IP and port to listen for incoming http connections; set blank to disable.");
      else
         cfg.add_options()
            (my->http_server_address_option_name.c_str(), bpo::value<string>(),
             "The local IP and port to listen for incoming http connections; leave blank to disable.");

      cfg.add_options()
            (my->https_server_address_option_name.c_str(), bpo::value<string>(),
             "The local IP and port to listen for incoming https connections; leave blank to disable.")

            ("https-certificate-chain-file", bpo::value<string>(),
             "Filename with the certificate chain to present on https connections. PEM format. Required for https.")

            ("https-private-key-file", bpo::value<string>(),
             "Filename with https private key in PEM format. Required for https")

            ("access-control-allow-origin", bpo::value<string>()->notifier([this](const string& v) {
                my->access_control_allow_origin = v;
                ilog("configured http with Access-Control-Allow-Origin: ${o}", ("o", my->access_control_allow_origin));
             }),
             "Specify the Access-Control-Allow-Origin to be returned on each request.")

            ("access-control-allow-headers", bpo::value<string>()->notifier([this](const string& v) {
                my->access_control_allow_headers = v;
                ilog("configured http with Access-Control-Allow-Headers : ${o}", ("o", my->access_control_allow_headers));
             }),
             "Specify the Access-Control-Allow-Headers to be returned on each request.")

            ("access-control-max-age", bpo::value<string>()->notifier([this](const string& v) {
                my->access_control_max_age = v;
                ilog("configured http with Access-Control-Max-Age : ${o}", ("o", my->access_control_max_age));
             }),
             "Specify the Access-Control-Max-Age to be returned on each request.")

            ("access-control-allow-credentials",
             bpo::bool_switch()->notifier([this](bool v) {
                my->access_control_allow_credentials = v;
                if (v) ilog("configured http with Access-Control-Allow-Credentials: true");
             })->default_value(false),
             "Specify if Access-Control-Allow-Credentials: true should be returned on each request.")
            ("max-body-size", bpo::value<uint32_t>()->default_value(1024*1024), "The maximum body size in bytes allowed for incoming RPC requests")
            ("verbose-http-errors", bpo::bool_switch()->default_value(false), "Append the error log to HTTP responses")
            ("http-validate-host", boost::program_options::value<bool>()->default_value(true), "If set to false, then any incoming \"Host\" header is considered valid")
            ("http-alias", bpo::value<std::vector<string>>()->composing(), "Additionaly acceptable values for the \"Host\" header of incoming HTTP requests, can be specified multiple times.  Includes http/s_server_address by default.")
            ("idle-http-connection-timeout-ms", bpo::value<uint32_t>()->default_value(5000), "Timeout in milliseconds to cut idle HTTP connections out; 0 means infinite")
            ("max-http-connections", bpo::value<uint32_t>()->default_value(100), "The maximum number of HTTP and WebSocket connections which is allowed to connect and keep alive; 0 means unlimited")
            ;
   }

   void http_plugin::plugin_initialize(const variables_map& options) {
      try {
         my->idle_connection_timeout_ms = options.at("idle-http-connection-timeout-ms").as<uint32_t>();
         my->max_connections = options.at("max-http-connections").as<uint32_t>();

         my->validate_host = options.at("http-validate-host").as<bool>();
         if( options.count( "http-alias" )) {
            const auto& aliases = options["http-alias"].as<vector<string>>();
            my->valid_hosts.insert(aliases.begin(), aliases.end());
         }

         tcp::resolver resolver( app().get_io_service());
         if( options.count( my->http_server_address_option_name ) && options.at( my->http_server_address_option_name ).as<string>().length()) {
            string lipstr = options.at( my->http_server_address_option_name ).as<string>();
            string host = lipstr.substr( 0, lipstr.find( ':' ));
            string port = lipstr.substr( host.size() + 1, lipstr.size());
            tcp::resolver::query query( tcp::v4(), host.c_str(), port.c_str());
            try {
               my->listen_endpoint = *resolver.resolve( query );
               ilog( "configured http to listen on ${h}:${p}", ("h", host)( "p", port ));
            } catch ( const boost::system::system_error& ec ) {
               elog( "failed to configure http to listen on ${h}:${p} (${m})",
                     ("h", host)( "p", port )( "m", ec.what()));
               throw;
            }

            // add in resolved hosts and ports as well
            if (my->listen_endpoint) {
               my->add_aliases_for_endpoint(*my->listen_endpoint, host, port);
            }
         }

         if( options.count( my->unix_socket_path_option_name ) && !options.at( my->unix_socket_path_option_name ).as<string>().empty()) {
            boost::filesystem::path sock_path = options.at(my->unix_socket_path_option_name).as<string>();
            if (sock_path.is_relative())
               sock_path = app().data_dir() / sock_path;
            my->unix_endpoint = asio::local::stream_protocol::endpoint(sock_path.string());
         }

         if( options.count( "https-server-address" ) && options.at( "https-server-address" ).as<string>().length()) {
            EOS_ASSERT(options.count("https-certificate-chain-file") &&
                       !options.at("https-certificate-chain-file").as<string>().empty(),
                       chain::plugin_config_exception,
                       "https-certificate-chain-file is required for HTTPS");
            EOS_ASSERT(options.count("https-private-key-file") &&
                       !options.at("https-private-key-file").as<string>().empty(),
                       chain::plugin_config_exception,
                       "https-private-key-file is required for HTTPS");

            string lipstr = options.at( my->https_server_address_option_name ).as<string>();
            string host = lipstr.substr( 0, lipstr.find( ':' ));
            string port = lipstr.substr( host.size() + 1, lipstr.size());
            tcp::resolver::query query( tcp::v4(), host.c_str(), port.c_str());
            try {
               my->https_listen_endpoint = *resolver.resolve( query );
               ilog( "configured https to listen on ${h}:${p} (TLS configuration will be validated momentarily)",
                     ("h", host)( "p", port ));
               my->https_cert_chain = options.at( "https-certificate-chain-file" ).as<string>();
               my->https_key = options.at( "https-private-key-file" ).as<string>();
            } catch ( const boost::system::system_error& ec ) {
               elog( "failed to configure https to listen on ${h}:${p} (${m})",
                     ("h", host)( "p", port )( "m", ec.what()));
               throw;
            }

            // add in resolved hosts and ports as well
            if (my->https_listen_endpoint) {
               my->add_aliases_for_endpoint(*my->https_listen_endpoint, host, port);
            }
         }

         my->max_body_size = options.at( "max-body-size" ).as<uint32_t>();
         verbose_http_errors = options.at( "verbose-http-errors" ).as<bool>();

         my->http_connections.clear();
         my->https_connections.clear();
         my->ws_connection_to_msgh_map.clear();
         my->wss_connection_to_msgh_map.clear();
      } FC_LOG_AND_RETHROW()
   }

   void http_plugin::plugin_startup() {
      if(my->listen_endpoint) {
         try {
            my->create_server_for_endpoint(*my->listen_endpoint, my->server);

            ilog("start listening for http requests");
            my->server.listen(*my->listen_endpoint);
            my->server.start_accept();
         } catch ( const fc::exception& e ){
            elog( "http service failed to start: ${e}", ("e",e.to_detail_string()));
            throw;
         } catch ( const std::exception& e ){
            elog( "http service failed to start: ${e}", ("e",e.what()));
            throw;
         } catch (...) {
            elog("error thrown from http io service");
            throw;
         }
      }

      if(my->unix_endpoint) {
         try {
            my->unix_server.clear_access_channels(websocketpp::log::alevel::all);
            my->unix_server.init_asio(&app().get_io_service());
            my->unix_server.set_max_http_body_size(my->max_body_size);
            my->unix_server.listen(*my->unix_endpoint);
            my->unix_server.set_http_handler([&](connection_hdl hdl) {
               my->handle_http_request<http_config::asio_local_with_stub_log, local_socket_endpoint>(my->unix_server.get_con_from_hdl(hdl));
            });
            my->unix_server.start_accept();
         } catch ( const fc::exception& e ){
            elog( "unix socket service failed to start: ${e}", ("e",e.to_detail_string()));
            throw;
         } catch ( const std::exception& e ){
            elog( "unix socket service failed to start: ${e}", ("e",e.what()));
            throw;
         } catch (...) {
            elog("error thrown from unix socket io service");
            throw;
         }
      }

      if(my->https_listen_endpoint) {
         try {
            my->create_server_for_endpoint(*my->https_listen_endpoint, my->https_server);
            my->https_server.set_tls_init_handler([this](websocketpp::connection_hdl hdl) -> ssl_context_ptr{
               return my->on_tls_init(hdl);
            });

            ilog("start listening for https requests");
            my->https_server.listen(*my->https_listen_endpoint);
            my->https_server.start_accept();
         } catch ( const fc::exception& e ){
            elog( "https service failed to start: ${e}", ("e",e.to_detail_string()));
            throw;
         } catch ( const std::exception& e ){
            elog( "https service failed to start: ${e}", ("e",e.what()));
            throw;
         } catch (...) {
            elog("error thrown from https io service");
            throw;
         }
      }
   }

   void http_plugin::plugin_shutdown() {
      if(my->server.is_listening())
         my->server.stop_listening();
      if(my->https_server.is_listening())
         my->https_server.stop_listening();
   }

   void http_plugin::add_handler(const string& url, const url_handler& handler) {
      ilog( "add api url: ${c}", ("c",url) );
      app().get_io_service().post([=](){
        my->url_handlers.insert(std::make_pair(url,handler));
      });
   }

   void http_plugin::handle_exception( const char *api_name, const char *call_name, const string& body, url_response_callback cb ) {
      try {
         try {
            throw;
         } catch (chain::unsatisfied_authorization& e) {
            error_results results{401, "UnAuthorized", error_results::error_info(e, verbose_http_errors)};
            cb( 401, fc::json::to_string( results ));
         } catch (chain::tx_duplicate& e) {
            error_results results{409, "Conflict", error_results::error_info(e, verbose_http_errors)};
            cb( 409, fc::json::to_string( results ));
         } catch (fc::eof_exception& e) {
            error_results results{422, "Unprocessable Entity", error_results::error_info(e, verbose_http_errors)};
            cb( 422, fc::json::to_string( results ));
            elog( "Unable to parse arguments to ${api}.${call}", ("api", api_name)( "call", call_name ));
            dlog("Bad arguments: ${args}", ("args", body));
         } catch (fc::exception& e) {
            error_results results{500, "Internal Service Error", error_results::error_info(e, verbose_http_errors)};
            cb( 500, fc::json::to_string( results ));
            if (e.code() != chain::greylist_net_usage_exceeded::code_value && e.code() != chain::greylist_cpu_usage_exceeded::code_value) {
               elog( "FC Exception encountered while processing ${api}.${call}",
                     ("api", api_name)( "call", call_name ));
               dlog( "Exception Details: ${e}", ("e", e.to_detail_string()));
            }
         } catch (std::exception& e) {
            error_results results{500, "Internal Service Error", error_results::error_info(fc::exception( FC_LOG_MESSAGE( error, e.what())), verbose_http_errors)};
            cb( 500, fc::json::to_string( results ));
            elog( "STD Exception encountered while processing ${api}.${call}",
                  ("api", api_name)( "call", call_name ));
            dlog( "Exception Details: ${e}", ("e", e.what()));
         } catch (...) {
            error_results results{500, "Internal Service Error",
               error_results::error_info(fc::exception( FC_LOG_MESSAGE( error, "Unknown Exception" )), verbose_http_errors)};
            cb( 500, fc::json::to_string( results ));
            elog( "Unknown Exception encountered while processing ${api}.${call}",
                  ("api", api_name)( "call", call_name ));
         }
      } catch (...) {
         std::cerr << "Exception attempting to handle exception for " << api_name << "." << call_name << std::endl;
      }
   }

   bool http_plugin::is_on_loopback() const {
      return (!my->listen_endpoint || my->listen_endpoint->address().is_loopback()) && (!my->https_listen_endpoint || my->https_listen_endpoint->address().is_loopback());
   }

   bool http_plugin::is_secure() const {
      return (!my->listen_endpoint || my->listen_endpoint->address().is_loopback());
   }

   void http_plugin::add_ws_handler(const string& url, ws_message_handler<basic_socket_endpoint> handler) {
      ilog("add websocket handler: ${c}", ("c", url));
      app().get_io_service().post([=]() {
          my->ws_message_handlers.insert(std::make_pair(url, handler));
      });
   }

   void http_plugin::add_wss_handler(const string& url, ws_message_handler<tls_socket_endpoint> handler) {
      ilog("add secure websocket handler: ${c}", ("c", url));
      app().get_io_service().post([=]() {
          my->wss_message_handlers.insert(std::make_pair(url, handler));
      });
   }

   void http_plugin::set_ws_connection_termination_handler(ws_connection_termination_handler<basic_socket_endpoint> handler) {
      my->plain_ws_connection_term_handler = handler;
   }

   void http_plugin::set_wss_connection_termination_handler(ws_connection_termination_handler<tls_socket_endpoint> handler) {
      my->tls_ws_connection_term_handler = handler;
   }

   bool http_plugin::verbose_errors()const {
      return verbose_http_errors;
   }

}
