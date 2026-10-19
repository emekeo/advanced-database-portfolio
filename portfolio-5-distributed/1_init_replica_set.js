print("=== Start the replica set ojougboh_rs with three members");
try {
  rs.initiate({
    _id: "ojougboh_rs",
    members: [
      { _id: 0, host: "localhost:27018" },
      { _id: 1, host: "localhost:27019" },
      { _id: 2, host: "localhost:27020" }
    ]
  });
  print("Replica set initiated");
} catch (error) {
  print("Already initiated: " + error.message);
}

print();
print("=== Wait for the members to elect a primary and for both secondaries to copy it");
while (rs.status().members.filter(member => member.stateStr === "PRIMARY").length < 1) sleep(1000);
while (rs.status().members.filter(member => member.stateStr === "SECONDARY").length < 2) sleep(1000);

printjson(
  rs.status().members.map(member => ({
    node: member.name,
    state: member.stateStr,
    health: member.health,
    votes: rs.conf().members.find(configured => configured.host === member.name).votes
  }))
);
