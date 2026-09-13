.pragma library
function arrange(devices, availableWidth, availableHeight) {
    var lookup={}, children={}, seen={}, result=[], cursor=0, deepest=0
    devices.forEach(function(d) { lookup[d.id]=d; children[d.id]=[] })
    devices.forEach(function(d) { if (children[d.parent] && d.parent!==d.id) children[d.parent].push(d) })
    function place(d, depth) {
        if (seen[d.id] || depth>16) return null
        seen[d.id]=true; deepest=Math.max(deepest,depth)
        var xs=[]
        children[d.id].forEach(function(child) { var x=place(child,depth+1); if (x!==null) xs.push(x) })
        var position=xs.length ? (xs[0]+xs[xs.length-1])/2 : cursor++
        result.push({device:d,slot:position,depth:depth})
        return position
    }
    devices.filter(function(d) { return !lookup[d.parent] }).forEach(function(d) { place(d,0) })
    devices.forEach(function(d) { if(!seen[d.id]) place(d,0) })
    var width=Math.max(availableWidth,cursor*142), cell=width/Math.max(1,cursor)
    var stride=Math.max(112, Math.min(145, ((availableHeight || 460)-18)/(deepest+1)))
    result.forEach(function(n) { n.x=(n.slot+0.5)*cell-66; n.y=n.depth*stride+8 })
    return {nodes:result,width:width,height:(deepest+1)*stride+18}
}
