/**
 *  @file contracts/infrasys/infrasys.identity_authority.cpp
 *  @author bezalel@infrablockchain.com
 *  @copyright defined in infrablockchain/LICENSE.txt
 */

#include "infrasys.hpp"

#include <infrablockchainlib/system_accounts.hpp>
#include <infrablockchainlib/identity_authority.hpp>

#include <eosiolib/dispatcher.hpp>

namespace infrablockchainsys {

    using infrablockchain::identity_authority_info;

    void system_contract::regidauth( const account_name identity_authority, const std::string& url, uint16_t location ) {

        eosio_assert( url.size() < 512, "url too long" );
        require_auth( identity_authority );

        auto idauth = _identity_authorities.find( identity_authority );

        if ( idauth != _identity_authorities.end() ) {
            _identity_authorities.modify( idauth, identity_authority, [&]( identity_authority_info& info ){
                info.is_authorized = false;
                info.url           = url;
                info.location      = location;
            });
        } else {
            _identity_authorities.emplace( identity_authority, [&]( identity_authority_info& info ){
                info.owner         = identity_authority;
                info.is_authorized = false;
                info.url           = url;
                info.location      = location;
            });
        }
    }

    void system_contract::authidauth( const account_name identity_authority ) {
        require_auth( _self );

        auto idauth = _identity_authorities.find( identity_authority );

        eosio_assert( idauth != _identity_authorities.end(), "not found registered identity authority" );
        eosio_assert( !idauth->is_authorized, "identity authority is already authorized" );

        _identity_authorities.modify( idauth, 0, [&]( identity_authority_info& info ){
            info.is_authorized = true;
        });
    }

    void system_contract::rmvidauth( const account_name identity_authority ) {
        require_auth( _self );

        auto idauth = _identity_authorities.find( identity_authority );

        eosio_assert( idauth != _identity_authorities.end(), "not found registered identity authority" );
        eosio_assert( idauth->is_authorized, "identity authority is already unauthorized" );

         _identity_authorities.modify( idauth, 0, [&]( identity_authority_info& info ){
            info.is_authorized = false;
        });
    }

} //namespace infrablockchainsys
