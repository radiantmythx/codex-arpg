class_name BuffManager
extends Node

var stats: Stats
var _active: Array = []

func _ready():
        set_physics_process(true)

func _physics_process(delta):
        for i in range(_active.size() - 1, -1, -1):
                var data = _active[i]
                if data.time > 0.0:
                        data.time -= delta
                        if data.time <= 0.0:
                                stats.remove_affix(data.affix)
                                _active.remove_at(i)

func apply_buff(buff: Buff):
        if not stats:
                return
        var affix = buff._create_affix()
        stats.apply_affix(affix)
        _active.append({"buff": buff, "affix": affix, "time": buff.duration})

func remove_buff(buff: Buff):
        for i in range(_active.size() - 1, -1, -1):
                var data = _active[i]
                if data.buff == buff:
                        stats.remove_affix(data.affix)
                        _active.remove_at(i)
