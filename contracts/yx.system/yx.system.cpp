#include "yx.system.hpp"
#include <yosemitelib/native_token.hpp>
#include <yosemitelib/system_accounts.hpp>
#include <yosemitelib/system_depository.hpp>
#include <yosemitelib/transaction_fee.hpp>
#include <eosiolib/dispatcher.hpp>
#include "yx.block_producer.cpp"
#include "yx.sys_depository.cpp"
#include "yx.identity_authority.cpp"
#include "yx.system_token.cpp"

namespace yosemitesys {
    using yosemite::yx_asset;

    system_contract::system_contract( account_name s )
            :native(s),
             _producers(_self,_self),
             _sys_depositories(_self,_self),
             _identity_authorities(_self,_self),
             _global(_self,_self)
    {
        _gstate = _global.exists() ? _global.get() : get_default_parameters();
    }

    yosemite_global_state system_contract::get_default_parameters() {
        yosemite_global_state dp;
        get_blockchain_parameters(dp);
        return dp;
    }

    system_contract::~system_contract() {
        _global.set( _gstate, _self );
    }

    void system_contract::setram( uint64_t max_ram_size ) {
        require_auth( _self );

        eosio_assert( _gstate.max_ram_size < max_ram_size, "ram may only be increased" ); /// decreasing ram might result market maker issues
        eosio_assert( max_ram_size < 1024ll*1024*1024*1024*1024, "ram size is unrealistic" );
        eosio_assert( max_ram_size > _gstate.total_ram_bytes_reserved, "attempt to set max below reserved" );

        _gstate.max_ram_size = max_ram_size;
        _global.set( _gstate, _self );
    }

    void system_contract::setparams( const eosio::blockchain_parameters& params ) {
        require_auth( YOSEMITE_SYSTEM_ACCOUNT );
        (eosio::blockchain_parameters&)(_gstate) = params;
        eosio_assert( 3 <= _gstate.max_authority_depth, "max_authority_depth should be at least 3" );
        set_blockchain_parameters( params );
    }

    void system_contract::setpriv( account_name account, uint8_t ispriv ) {
        require_auth( _self );
        set_privileged( account, ispriv );
    }

    /**
     *  Called after a new account is created. This code enforces resource-limits rules
     *  for new accounts as well as new account naming conventions.
     *
     *  Account names containing '.' symbols must have a suffix equal to the name of the creator.
     *
     */
    void native::newaccount( account_name     creator,
                             account_name     newact
            /*  no need to parse authorites
            const authority& owner,
            const authority& active*/ ) {

        if( creator != _self ) {
            auto tmp = newact >> 4;
            bool has_dot = false;

            for( uint32_t i = 0; i < 12; ++i ) {
                has_dot |= !(tmp & 0x1f);
                tmp >>= 5;
            }
            if( has_dot ) { // or is less than 12 characters
                auto suffix = eosio::name_suffix(newact);
                if( suffix == newact ) {
                    eosio_assert( false, "only system account can create accounts having less than 12 characters" );
                } else {
                    eosio_assert( creator == suffix, "only suffix may create this account" );
                }
            }
        }

        // no resource limit, Yosemite is transaction-fee based blockchain.
        set_resource_limits( newact, -1, -1, -1 );
    }

} /// yosemitesys

EOSIO_ABI( yosemitesys::system_contract,
           // native.hpp (newaccount definition is actually in yx.system.cpp)
           (newaccount)(updateauth)(deleteauth)(linkauth)(unlinkauth)(canceldelay)(onerror)
           // yx.system.cpp
           (setram)(setparams)(setpriv)
           // yx.block_producer.cpp
           (onblock)(regproducer)(authproducer)(unregprod)(rmvproducer)(claimrewards)
           // yx.sys_depository.cpp
           (regsysdepo)(authsysdepo)(rmvsysdepo)
           // yx.identity_authority.cpp
           (regidauth)(authidauth)(rmvidauth)
           // yx.system_token.cpp
           (addsystoken)(rmvsystoken)
)
