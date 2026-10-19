# Portfolio 5 – Distributed and Cloud Database

Portfolio 4 put the clinical record (vitals, notes, patient background) in MongoDB on a single server. If that server fails, nurses cannot record observations on the ward. This portfolio runs the same data on a **three-member MongoDB replica set** and shows replication, consistency and availability working, then discusses sharding and how Ojougboh would deploy both databases.

The three members run on one laptop for the demonstration. In a real deployment each would be a separate machine, as described in section 5.

| Member | Port | Role at the start |
|---|---|---|
| node 1 | 27018 | Elected primary: takes all writes |
| node 2 | 27019 | Secondary: a full copy, kept up to date from the primary |
| node 3 | 27020 | Secondary: a full copy, kept up to date from the primary |

Each member keeps a full copy of `ojougboh_clinical`. The primary records every change in its **oplog** (operation log), and the secondaries copy and replay it. The application connects to the set as a whole (`?replicaSet=ojougboh_rs`) and the driver finds the primary itself.

## 1. Replication

`2_replication.js` adds a nurse's vitals reading to inpatient `OGH/2026/0005`'s admission document on the primary, with write concern `majority`, then connects to each member directly and reads the admission back.

In the recorded run (`evidence/2_replication_output.txt`) the write went to the primary, 27018. One second later all three members held 5 readings and had the new one. A write on the primary reaches every copy without the application doing anything.

## 2. Consistency

Copies on different machines are updated one after another, so for a moment they can disagree. `3_consistency.js` makes this visible by turning one secondary into a **delayed member** that applies changes 20 seconds late, as a copy at a second site on a slow link might.

| Part | What happens | Shows |
|---|---|---|
| 1 | A reading is written with `w: 1` (only the primary confirms). Two seconds later the primary and the up-to-date secondary have it; the delayed secondary does not. 27 seconds later all three have it | **Stale read**, then **eventual consistency** |
| 2 | A write with `w: "majority"` is confirmed quickly by the primary and the up-to-date secondary. A write with `w: 3` waits for the delayed member, times out after 5 seconds, but is still saved on the primary | The **trade-off** between how many copies confirm a write and how long the application waits |

In the recorded run (`evidence/3_consistency_output.txt`) 27020 was the delayed member. Two seconds after the `w: 1` write, it did not have the reading while the other two did; at 27 seconds all three had it. The `majority` write was confirmed in 11 ms. The `w: 3` write timed out after 5,031 ms with "waiting for replication timed out", and the reading was on the primary anyway.

For Ojougboh this means:

- Ward vitals and notes are written with `w: "majority"`. Once a majority has the write, it survives the loss of any one member, and waiting for two local members costs only milliseconds.
- `w: 3` (every copy) would stop the ward whenever any one member is slow or down, which defeats the point of having copies.
- Doctors read from the **primary** (the default), so they always see the latest observations. Reading from secondaries is kept for reports, such as a weekly fever count, where a few seconds of delay does not matter.

The script puts the delayed member back to normal at the end.

## 3. Availability: failover

With one server, a failure stops the ward. With three, the remaining members hold an **election** and one of them becomes primary.

| Step | Action | Evidence |
|---|---|---|
| a | All three members up | `4a_status_before.txt` |
| b | The primary is shut down. About 10 seconds later the other two elect a new primary | `4b_status_after_stop.txt` |
| c | A new reading is written through the same connection string. It succeeds on the new primary and reaches the remaining secondary; the stopped member is reported as not reachable | `4c_write_during_failure.txt` |
| d | The stopped member is started again. It rejoins as a secondary and copies the reading it missed | `4d_status_after_restart.txt` |

In the recorded run:

- Before: 27018 was primary, and all three members held 8 readings.
- After 27018 was shut down: it showed as `(not reachable/healthy)`, and **27019 had been elected primary**. No readings were lost.
- During the failure: the write went to 27019 through the same connection string and reached 27020, giving 11 readings.
- After the restart: 27018 rejoined as a secondary with all 11 readings, including the one written while it was down.

A majority (2 of 3) is needed to elect a primary. If two members fail, the last one stays a secondary and refuses writes rather than risk two primaries accepting different data (**split brain**). This is why replica sets have an odd number of voting members.

## 4. Sharding (discussion)

Sharding splits a collection across several replica sets, each holding part of the data. Ojougboh does not need it: even with readings every few hours for every inpatient, a single hospital produces a few million vitals readings a year, which one replica set handles easily. Section 1 of Portfolio 2 tested PostgreSQL with 4.2 million rows on a laptop.

It would be needed if Ojougboh became a group of hospitals sharing one clinical record system. The design would then be:

| Decision | Choice | Reason |
|---|---|---|
| Shard key | `{ facility: 1, hospital_no: 1 }` | Every common query asks for one patient's record, so it goes to one shard only. Adding `facility` first keeps each hospital's patients together |
| Zones | One zone per hospital or region, pinned to servers near it | A doctor in Agbor reads from a server near Agbor; data can be kept in a given state or in Nigeria to meet the Nigeria Data Protection Act |
| Not `recorded_at` | | Every new reading has the latest time, so all writes would go to the last shard (a hotspot) |
| Not `_id` alone | | Spreads writes evenly, but a patient's record would be spread over every shard, so every read would ask all of them |

The relational data in PostgreSQL would not be sharded. Invoices, stock and bookings need transactions and foreign keys across tables, which sharding makes much harder (Portfolio 3).

## 5. Deployment for Ojougboh (discussion)

### Where each part runs

| Component | Where | Why |
|---|---|---|
| PostgreSQL primary | Server room at the hospital | Registration, booking, pharmacy and billing must keep working when the internet is down, which happens often in Agbor |
| PostgreSQL standby | Second server at the hospital, streaming replication | Takes over if the primary fails. Streaming replication sends the write-ahead log, the PostgreSQL equivalent of the oplog |
| PostgreSQL backups | Nightly to cloud storage in a Nigerian region, plus weekly to an encrypted disk kept off site | Protects against fire, theft or ransomware at the site |
| MongoDB members 1 and 2 | Two servers at the hospital, on different power circuits with UPS | Wards keep recording observations during an internet outage |
| MongoDB member 3 | Cloud, Nigerian region (for example MongoDB Atlas or a VM) | An off-site copy, and the third vote for elections |

Two of the three MongoDB members are on site on purpose. If the internet link fails, the hospital still holds a majority, so it keeps a primary and keeps writing. The cloud member catches up from the oplog when the link returns. If instead two members were in the cloud, an internet outage would leave the hospital with a minority, and the wards could not write at all.

Power cuts are the other main risk. Each server needs a UPS long enough for the generator to start. Members must not share a single power circuit.

### CAP theorem

During a network partition, a distributed database must choose between **consistency** (every read sees the latest write) and **availability** (every request gets an answer).

- MongoDB with `w: "majority"` and reads from the primary chooses **consistency**: the side of a partition without a majority stops accepting writes. The design above puts the majority on site, so in the likely partition (the hospital losing its internet link) the side without a majority is the cloud member, and the wards are not affected.
- PostgreSQL with one primary and a standby also chooses consistency. Only the primary accepts writes, and failover to the standby is a deliberate step, so two servers never both accept bills or bookings.

For money, stock and bookings this is the right choice: a double-booked doctor or a payment recorded twice is worse than a short pause. For vitals the same choice is acceptable because the majority is on site.

## How to run

MongoDB 9.0 must be installed (Portfolio 4). The Windows service on port 27017 can keep running; the replica set uses ports 27018–27020. Commands are for Git Bash, from the repository root. In Windows PowerShell, replace `> file 2>&1` with `| Out-File -Encoding utf8 file`.

**1. Create a data folder for each member (once):**

```bash
mkdir -p "$HOME/ojougboh-rs/node1" "$HOME/ojougboh-rs/node2" "$HOME/ojougboh-rs/node3"
```

**2. Start each member in its own terminal and leave the three windows open:**

```bash
"/c/Program Files/MongoDB/Server/9.0/bin/mongod.exe" --replSet ojougboh_rs --port 27018 --dbpath "$HOME/ojougboh-rs/node1" --bind_ip localhost --wiredTigerCacheSizeGB 0.25
```

```bash
"/c/Program Files/MongoDB/Server/9.0/bin/mongod.exe" --replSet ojougboh_rs --port 27019 --dbpath "$HOME/ojougboh-rs/node2" --bind_ip localhost --wiredTigerCacheSizeGB 0.25
```

```bash
"/c/Program Files/MongoDB/Server/9.0/bin/mongod.exe" --replSet ojougboh_rs --port 27020 --dbpath "$HOME/ojougboh-rs/node3" --bind_ip localhost --wiredTigerCacheSizeGB 0.25
```

`--wiredTigerCacheSizeGB 0.25` keeps the three members from using most of the laptop's memory.

**3. In a fourth terminal, start the replica set and load the Portfolio 4 data into it:**

```bash
mongosh --quiet --port 27018 --file portfolio-5-distributed/1_init_replica_set.js > portfolio-5-distributed/evidence/1_init_output.txt 2>&1
```

```bash
mongosh "mongodb://localhost:27018,localhost:27019,localhost:27020/?replicaSet=ojougboh_rs" --quiet --file portfolio-4-nosql/1_load.js > portfolio-5-distributed/evidence/1_load_output.txt 2>&1
```

**4. Replication and consistency** (the second takes about 40 seconds):

```bash
mongosh "mongodb://localhost:27018,localhost:27019,localhost:27020/?replicaSet=ojougboh_rs" --quiet --file portfolio-5-distributed/2_replication.js > portfolio-5-distributed/evidence/2_replication_output.txt 2>&1
```

```bash
mongosh "mongodb://localhost:27018,localhost:27019,localhost:27020/?replicaSet=ojougboh_rs" --quiet --file portfolio-5-distributed/3_consistency.js > portfolio-5-distributed/evidence/3_consistency_output.txt 2>&1
```

**5. Failover:**

```bash
mongosh "mongodb://localhost:27018,localhost:27019,localhost:27020/?replicaSet=ojougboh_rs" --quiet --file portfolio-5-distributed/4_status.js > portfolio-5-distributed/evidence/4a_status_before.txt 2>&1
```

Open `4a_status_before.txt` and see which port is `PRIMARY` (27018 in the recorded run). Shut that member down. Ctrl+C in its window does not always reach `mongod.exe` from Git Bash, so ask the server to stop itself:

```bash
mongosh --port 27018 --quiet --eval "db.getSiblingDB('admin').shutdownServer({ force: true })"
```

It answers `MongoNetworkError: read ECONNRESET`, because the server closes the connection as it stops. Wait 15 seconds, then:

```bash
mongosh "mongodb://localhost:27018,localhost:27019,localhost:27020/?replicaSet=ojougboh_rs" --quiet --file portfolio-5-distributed/4_status.js > portfolio-5-distributed/evidence/4b_status_after_stop.txt 2>&1
```

```bash
mongosh "mongodb://localhost:27018,localhost:27019,localhost:27020/?replicaSet=ojougboh_rs" --quiet --file portfolio-5-distributed/2_replication.js > portfolio-5-distributed/evidence/4c_write_during_failure.txt 2>&1
```

Start the stopped member again with the same command as in step 2, wait 15 seconds, then:

```bash
mongosh "mongodb://localhost:27018,localhost:27019,localhost:27020/?replicaSet=ojougboh_rs" --quiet --file portfolio-5-distributed/4_status.js > portfolio-5-distributed/evidence/4d_status_after_restart.txt 2>&1
```

**To finish,** shut each member down the same way (`--port 27018`, `27019`, `27020`). Deleting `$HOME/ojougboh-rs` removes the replica set's data. The Portfolio 4 database on port 27017 is not affected by any of this.

## Files

| File | Purpose |
|------|---------|
| `1_init_replica_set.js` | Creates the three-member replica set and waits for a primary and two secondaries |
| `2_replication.js` | Writes a vitals reading on the primary and reads it back from every member |
| `3_consistency.js` | Stale reads from a delayed member, and `w: 1`, `w: "majority"` and `w: 3` compared |
| `4_status.js` | Shows each member's state and what it holds; run before, during and after the failover |
| `evidence/` | Output of every step |
