/**
 *  @file contracts/infrasys/infrasys.hpp
 *  @author bezalel@infrablockchain.com
 *  @copyright defined in infrablockchain/LICENSE.txt
 */
#pragma once

#include "infrasys.native.hpp"
#include <infrablockchainlib/native_token.hpp>
#include <infrablockchainlib/system_accounts.hpp>
#include <infrablockchainlib/identity_authority.hpp>
#include <eosiolib/asset.hpp>
#include <eosiolib/time.hpp>
#include <eosiolib/privileged.hpp>
#include <eosiolib/singleton.hpp>

#include <string>

namespace infrablockchainsys {

    using eosio::asset;
    using eosio::symbol_type;
    using eosio::indexed_by;
    using eosio::const_mem_fun;
    using eosio::block_timestamp;
    using infrablockchain::identity_authority_table;

    static const uint32_t INFRABLOCKCHAIN_MAX_ELECTED_BLOCK_PRODUCER_COUNT = 5;

    struct infrablockchain_global_state : eosio::blockchain_parameters {
        uint64_t free_ram()const { return max_ram_size - total_ram_bytes_reserved; }

        uint64_t             max_ram_size = 64ll*1024 * 1024 * 1024;
        uint64_t             total_ram_bytes_reserved = 0;
        int64_t              total_ram_stake = 0;

        block_timestamp      last_producer_schedule_update;
        uint32_t             total_unpaid_blocks = 0; /// all blocks which have been produced but not paid
        uint16_t             last_producer_schedule_size = 0;
        /* deprecated */ double total_producer_vote = 0; /// the sum of all producer votes (un-weighted sum)
        /* deprecated */ double total_producer_vote_weight = 0; /// the sum of all producer votes (weighted sum for vote decay)

        // explicit serialization macro is not necessary, used here only to improve compilation time
        EOSLIB_SERIALIZE_DERIVED( infrablockchain_global_state, eosio::blockchain_parameters,
                                  (max_ram_size)(total_ram_bytes_reserved)(total_ram_stake)
                                          (last_producer_schedule_update)(total_unpaid_blocks)
                                          (last_producer_schedule_size)(total_producer_vote)(total_producer_vote_weight) )
    };

    struct producer_info {
        account_name          owner;
        double                total_votes = 0;
        double                total_votes_weight = 0;
        eosio::public_key     producer_key; /// a packed public key object
        bool                  is_active = true;
        bool                  is_trusted_seed = false; // authorized flag for permissioned setup
        std::string           url;
        uint32_t              unpaid_blocks = 0;
        uint64_t              last_claim_time = 0;
        uint16_t              location = 0;

        uint64_t primary_key() const { return owner;                                   }
        double   by_votes() const    { return is_active ? -total_votes_weight : total_votes_weight;  }
        bool     active() const      { return is_active;                               }
        void     deactivate()        { producer_key = public_key(); is_active = false; }

        // explicit serialization macro is not necessary, used here only to improve compilation time
        EOSLIB_SERIALIZE( producer_info, (owner)(total_votes)(total_votes_weight)(producer_key)(is_active)(is_trusted_seed)
                (url)(unpaid_blocks)(last_claim_time)(location) )
    };

    typedef eosio::multi_index< N(producers), producer_info,
            indexed_by<N(prototalvote), const_mem_fun<producer_info, double, &producer_info::by_votes>  >
    >  producers_table;

    typedef eosio::singleton<N(global), infrablockchain_global_state> global_state_singleton;

    class system_contract : public native {
    private:
        producers_table          _producers;
        identity_authority_table _identity_authorities;
        global_state_singleton   _global;

        infrablockchain_global_state    _gstate;

    public:
        system_contract( account_name s );
        ~system_contract();

        void setram( uint64_t max_ram_size );

        void setparams( const eosio::blockchain_parameters& params );

        void setpriv( account_name account, uint8_t ispriv );


        // Block Producers (infrasys.block_producer.cpp)

        void onblock( block_timestamp timestamp, account_name producer );
        // const block_header& header ); /// only parse first 3 fields of block header

        void regproducer( const account_name producer, const public_key& producer_key, const std::string& url, uint16_t location );

        void unregprod( const account_name producer );

        void authproducer( const account_name producer );

        void rmvproducer( account_name producer );

        void claimrewards( const account_name& owner );

        // Identity Authorities (infrasys.identity_authority.cpp)

        void regidauth( const account_name identity_authority, const std::string& url, uint16_t location );

        void authidauth( const account_name identity_authority );

        void rmvidauth( const account_name identity_authority );


        // System Token Management (infrasys.system_token.cpp)

        void addsystoken( const account_name token, const uint32_t weight );

        void rmvsystoken( const account_name token );


        // Transaction Fee Management (infrasys.transaction_fee.cpp)

        void settxfee( const account_name code, const action_name action, const int32_t value, const uint32_t feetype );

        void unsettxfee( const account_name code, const action_name action );

    private:
        void update_elected_producers( block_timestamp timestamp );

        static infrablockchain_global_state get_default_parameters();
    };

} /// infrablockchainsys
