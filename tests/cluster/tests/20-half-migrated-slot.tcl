# Tests for fixing migrating slot at all stages:
# 1. when migration is half inited on "migrating" node
# 2. when migration is half inited on "importing" node
# 3. migration inited, but not finished
# 4. migration is half finished on "migrating" node
# 5. migration is half finished on "importing" node
source "../tests/includes/init-tests.tcl"
source "../tests/includes/utils.tcl"

test "Create a 2 nodes cluster" {
    create_cluster 2 0
}

test "Cluster is up" {
    assert_cluster_state ok
}

set cluster [redis_cluster 127.0.0.1:[get_instance_attrib redis 0 port]]
catch {unset nodefrom}
catch {unset nodeto}

proc reset_cluster {} {
    uplevel 1 {
        $cluster refresh_nodes_map
        array set nodefrom [$cluster masternode_for_slot 609]
        array set nodeto [$cluster masternode_notfor_slot 609]
    }
}

reset_cluster

$cluster set aga xyz

test "Half init migration in 'migrating' is fixable" {
    $nodefrom(link) cluster setslot 609 migrating $nodeto(id)
    fix_cluster $nodefrom(addr)
    assert {[$cluster get aga] eq "xyz"}
}

test "Half init migration in 'importing' is fixable" {
    $nodeto(link) cluster setslot 609 importing $nodefrom(id)
    fix_cluster $nodefrom(addr)
    assert {[$cluster get aga] eq "xyz"}
}

test "Init migration and move key" {
    $nodefrom(link) cluster setslot 609 migrating $nodeto(id)
    $nodeto(link) cluster setslot 609 importing $nodefrom(id)
    $nodefrom(link) migrate $nodeto(host) $nodeto(port) aga 0 10000
    assert {[$cluster get aga] eq "xyz"}
    fix_cluster $nodefrom(addr)
    assert {[$cluster get aga] eq "xyz"}
}

reset_cluster

test "Move key again" {
    $nodefrom(link) cluster setslot 609 migrating $nodeto(id)
    $nodeto(link) cluster setslot 609 importing $nodefrom(id)
    $nodefrom(link) migrate $nodeto(host) $nodeto(port) aga 0 10000
    assert {[$cluster get aga] eq "xyz"}
}

test "Half-finish migration" {
    # half finish migration on 'migrating' node
    $nodefrom(link) cluster setslot 609 node $nodeto(id)
    fix_cluster $nodefrom(addr)
    assert {[$cluster get aga] eq "xyz"}
}

reset_cluster

test "Move key back" {
    # 'aga' key is in 609 slot
    $nodefrom(link) cluster setslot 609 migrating $nodeto(id)
    $nodeto(link) cluster setslot 609 importing $nodefrom(id)
    $nodefrom(link) migrate $nodeto(host) $nodeto(port) aga 0 10000
    assert {[$cluster get aga] eq "xyz"}
}

test "Half-finish importing" {
    # Now we half finish 'importing' node
    $nodeto(link) cluster setslot 609 node $nodeto(id)
    fix_cluster $nodefrom(addr)
    assert {[$cluster get aga] eq "xyz"}
}
