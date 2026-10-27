#pragma once

#include <array>
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <type_traits>

/// This is a single producer single consumer ring buffer that allows
/// to access historic (delayed) values
template<typename T, std::size_t RingSize>
    requires std::is_trivially_copyable_v<T>
class DelayRing {
    static_assert(RingSize > 0);
    static_assert(std::atomic<std::uint8_t>::is_always_lock_free);

  public:
    /// Push new data to the ring
    /// Must be called from a single thread only
    void push(const T& data) {
        size_t write = m_writeIndex.load(std::memory_order_relaxed);
        Slot& slot = m_ring[write % RingSize];
        const std::size_t version = slot.version.load(std::memory_order_relaxed);
        slot.version.store(version + 1, std::memory_order_seq_cst);
        const auto* pBytes = reinterpret_cast<const std::uint8_t*>(&data);
        for (std::size_t i = 0; i < sizeof(T); ++i) {
            slot.bytes[i].store(pBytes[i], std::memory_order_seq_cst);
        }
        slot.version.store(version + 2, std::memory_order_seq_cst);
        m_writeIndex.store(write + 1, std::memory_order_release);
        if (m_level.load(std::memory_order_relaxed) < RingSize) {
            m_level.fetch_add(1, std::memory_order_release);
        }
        return;
    }

    /// returns true on success and a delayed value via pData
    /// getAt(0) returns the most recent value
    /// getAt(1) returns the value that has been pushed before
    /// keep 'at' small compared to kRingSize to make a ring lap during the
    /// call of getAt() unlikely
    /// Must be called from a single thread only
    bool getAt(std::size_t at, T* pData) {
        if (!pData) {
            return false;
        }
        // not enough data available
        if (m_level.load(std::memory_order_acquire) <= at) {
            return false;
        }

        for (;;) {
            // snapshot the published write count (acquire)
            const size_t writeBefore = m_writeIndex.load(std::memory_order_acquire);

            // compute read index (unsigned arithmetic handles wrap)
            const size_t read = writeBefore - 1 - at;
            const Slot& slot = m_ring[read % RingSize];
            const std::size_t versionBefore =
                    slot.version.load(std::memory_order_seq_cst);
            if (versionBefore & 1) {
                continue;
            }

            std::array<std::uint8_t, sizeof(T)> bytes{};
            for (std::size_t i = 0; i < sizeof(T); ++i) {
                bytes[i] = slot.bytes[i].load(std::memory_order_seq_cst);
            }
            const std::size_t versionAfter =
                    slot.version.load(std::memory_order_seq_cst);
            if (versionBefore != versionAfter) {
                continue;
            }

            // re-check the published write count (acquire)
            const size_t writeAfter = m_writeIndex.load(std::memory_order_acquire);

            // loop condition below will retry only if producer could have overwritten the slot
            if (writeAfter - writeBefore >= RingSize - at) {
                continue;
            }

            if (m_level.load(std::memory_order_relaxed) <= at) {
                return false;
            }
            std::memcpy(pData, bytes.data(), sizeof(T));
            return true;
        }
    }

    /// Clears the ring, can be called from any thread
    void reset() {
        m_level.store(0, std::memory_order_release);
    }

  private:
    struct Slot {
        std::atomic<std::size_t> version{0};
        std::array<std::atomic<std::uint8_t>, sizeof(T)> bytes{};
    };

    std::array<Slot, RingSize> m_ring;
    std::atomic<std::size_t> m_writeIndex{0};
    std::atomic<std::size_t> m_level{0};
};
