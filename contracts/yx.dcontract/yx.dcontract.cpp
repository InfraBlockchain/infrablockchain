/**
 *  @copyright defined in LICENSE
 */

#include "yx.dcontract.hpp"

namespace yosemite {
    static const int MAX_SIGNERS = 32;

    void digital_contract::check_signers_param(const vector <account_name> &signers, flat_set <account_name> &duplicates) {
        eosio_assert(static_cast<uint32_t>(!signers.empty()), "signers cannot be empty");
        eosio_assert(static_cast<uint32_t>(signers.size() <= MAX_SIGNERS), "too many signers");

        for (auto signer : signers) {
            eosio_assert(static_cast<uint32_t>(is_account(signer)), "signer account does not exist");
            auto result = duplicates.insert(signer);
            eosio_assert(static_cast<uint32_t>(result.second), "duplicated signer account exists");
        }
    }

    void digital_contract::create(const dcid &dc_id, const string &conhash, const string &adddochash,
                                  const vector<account_name> &signers, const time_point_sec &expiration,
                                  identity::identity_type_t signer_type, identity::identity_kyc_t signer_kyc, uint8_t options) {
        eosio_assert(static_cast<uint32_t>(!conhash.empty()), "conhash cannot be empty");
        eosio_assert(static_cast<uint32_t>(conhash.size() <= 256), "conhash is too long");
        eosio_assert(static_cast<uint32_t>(adddochash.size() <= 256), "additional conhash is too long");
        eosio_assert(static_cast<uint32_t>(expiration > time_point_sec(now() + 60)), "wrong expiration : already expired or too close to now");
        eosio_assert(static_cast<uint32_t>(options == 0), "options is currently reserved");
        flat_set<account_name> empty_duplicates;
        check_signers_param(signers, empty_duplicates);

        require_auth(dc_id.creator);

        dcontract_index dcontract_idx{get_self(), dc_id.creator};
        eosio_assert(static_cast<uint32_t>(dcontract_idx.find(dc_id.sequence) == dcontract_idx.end()),
                     "digital contract with the sequence already exists");

        dcontract_idx.emplace(get_self(), [&](auto &i) {
            i.sequence = dc_id.sequence;
            i.conhash = conhash;
            i.adddochash = adddochash;
            std::copy(signers.begin(), signers.end(), std::back_inserter(i.signers));
            i.expiration = expiration;
            i.signer_type = signer_type;
            i.signer_kyc = signer_kyc;
            i.options = options;
        });
    }

    void digital_contract::addsigners(const dcid &dc_id, const vector<account_name> &signers) {
        require_auth(dc_id.creator);

        dcontract_index dcontract_idx{get_self(), dc_id.creator};
        const auto &info = dcontract_idx.get(dc_id.sequence, "digital contract does not exist");
        eosio_assert(static_cast<uint32_t>(!info.is_signed()), "digital contract is already signed by at least one signer");
        eosio_assert(static_cast<uint32_t>(info.expiration > time_point_sec(now())), "digital contract is expired");
        // check duplicated signer
        flat_set<account_name> duplicates{info.signers.begin(), info.signers.end()};
        check_signers_param(signers, duplicates);
        eosio_assert(static_cast<uint32_t>(info.signers.size() + signers.size() <= MAX_SIGNERS), "too many signers in total");

        dcontract_idx.modify(info, 0, [&](auto &i) {
            std::copy(signers.begin(), signers.end(), std::back_inserter(i.signers));
        });
    }

    void digital_contract::sign(const dcid &dc_id, account_name signer, const string &signerinfo) {
        eosio_assert(static_cast<uint32_t>(signerinfo.size() <= 256), "signerinfo is too long");
        eosio_assert(static_cast<uint32_t>(is_account(dc_id.creator)), "creator account does not exist");

        require_auth(signer);

        dcontract_index dcontract_idx{get_self(), dc_id.creator};
        const auto &info = dcontract_idx.get(dc_id.sequence, "digital contract does not exist");
        eosio_assert(static_cast<uint32_t>(info.expiration > time_point_sec(now())), "digital contract is expired");
        const auto &itr = std::find(info.signers.begin(), info.signers.end(), signer);
        eosio_assert(static_cast<uint32_t>(itr != info.signers.end()),
                     "not designated signer");
        auto index = std::distance(info.signers.begin(), itr);
        eosio_assert(static_cast<uint32_t>(std::find(info.done_signers.begin(), info.done_signers.end(), index) == info.done_signers.end()),
                     "digital contract is already signed by the signer");
        // account type, KYC check
        eosio_assert(static_cast<uint32_t>(identity::is_account_type(signer, info.signer_type)), "signer is not the required account type");
        eosio_assert(static_cast<uint32_t>(identity::has_all_kyc_status(signer, info.signer_kyc)), "signer does not have required KYC status");

        dcontract_idx.modify(info, 0, [&](auto &i) {
            i.done_signers.push_back(static_cast<uint8_t>(index));
        });

        dcontract_signer_index dc_signer_index{get_self(), signer};
        dc_signer_index.emplace(get_self(), [&](auto &i) {
            i.id = dc_signer_index.available_primary_key();
            i.dc_id = dc_id;
            i.signerinfo = signerinfo;
        });
    }

    void digital_contract::upadddochash(const dcid &dc_id, const string &adddochash) {
        eosio_assert(static_cast<uint32_t>(adddochash.size() <= 256), "adddochash is too long");

        require_auth(dc_id.creator);

        dcontract_index dcontract_idx{get_self(), dc_id.creator};
        const auto &info = dcontract_idx.get(dc_id.sequence, "digital contract does not exist");

        dcontract_idx.modify(info, 0, [&](auto &i) {
            i.adddochash.clear();
            i.adddochash = adddochash;
        });
    }

    void digital_contract::remove(const dcid &dc_id) {
        require_auth(dc_id.creator);

        dcontract_index dcontract_idx{get_self(), dc_id.creator};
        const auto &info = dcontract_idx.get(dc_id.sequence, "digital contract does not exist");

        for (auto signer_index : info.done_signers) {
            dcontract_signer_index dc_signer_index{get_self(), info.signers[signer_index]};
            auto dcid_index = dc_signer_index.get_index<N(dcids)>();
            auto itr = dcid_index.find(dc_id.to_uint128());
            if (itr != dcid_index.end()) {
                dcid_index.erase(itr);
            }
        }

        dcontract_idx.erase(info);
    }
}

EOSIO_ABI(yosemite::digital_contract, (create)(addsigners)(sign)(upadddochash)(remove)
)
