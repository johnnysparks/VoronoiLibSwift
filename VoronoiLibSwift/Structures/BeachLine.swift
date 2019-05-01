//
//  BeachLine.swift
//  VoronoiLibSwift
//
//  Created by Wilhelm Oks on 19.04.19.
//  Copyright © 2019 Wilhelm Oks. All rights reserved.
//

final class BeachSection {
    let site: FortuneSite
    var edge: VEdge?
    //NOTE: this will change
    var circleEvent: FortuneCircleEvent?
    
    init(site: FortuneSite) {
        self.site = site
    }
}

final class BeachLine {
    private let beachLine = RBTree<BeachSection>()
    
    init() {
        
    }
    
    func addBeachSection(siteEvent: FortuneSiteEvent, eventQueue: MinHeap<FortuneEvent>, deleted: HashSet<FortuneCircleEvent>, edges: LinkedList<VEdge>) {
        let site = siteEvent.site
        let x = site.x
        let directrix = site.y
    
        var leftSection: RBTreeNode<BeachSection>? = nil
        var rightSection: RBTreeNode<BeachSection>? = nil
        var node = beachLine.root
    
        //find the parabola(s) above this site
        while node != nil && leftSection == nil && rightSection == nil {
            let distanceLeft = BeachLine.leftBreakpoint(node: node!, directrix: directrix) - x
            if distanceLeft > 0 {
                //the new site is before the left breakpoint
                if node?.left == nil {
                    rightSection = node
                } else {
                    node = node?.left
                }
                continue
            }
    
            let distanceRight = x - BeachLine.rightBreakpoint(node: node!, directrix: directrix)
            if distanceRight > 0 {
                //the new site is after the right breakpoint
                if node?.right == nil {
                    leftSection = node
                } else {
                    node = node?.right
                }
                continue
            }
    
            //the point lies below the left breakpoint
            if ParabolaMath.approxEqual(distanceLeft, 0) {
                leftSection = node?.previous
                rightSection = node
                continue
            }
    
            //the point lies below the right breakpoint
            if ParabolaMath.approxEqual(distanceRight, 0) {
                leftSection = node
                rightSection = node?.next
                continue
            }
    
            // distance Right < 0 and distance Left < 0
            // this section is above the new site
            leftSection = node
            rightSection = node
        }
    
        //our goal is to insert the new node between the
        //left and right sections
        let section = BeachSection(site: site)
    
        //left section could be nil, in which case this node is the first
        //in the tree
        let newSection = beachLine.insertSuccessor(successorNode: leftSection, successorData: section)
    
        //new beach section is the first beach section to be added
        if leftSection == nil && rightSection == nil {
            return
        }
    
        //main case:
        //if both left section and right section point to the same valid arc
        //we need to split the arc into a left arc and a right arc with our
        //new arc sitting in the middle
        if leftSection != nil && leftSection === rightSection {
            //if the arc has a circle event, it was a false alarm.
            //remove it
            if let leftSectionDataCircleEvent = leftSection!.data.circleEvent {
                deleted.add(leftSectionDataCircleEvent)
                leftSection?.data.circleEvent = nil
            }
        
            //we leave the existing arc as the left section in the tree
            //however we need to insert the right section defined by the arc
            let copy = BeachSection(site: leftSection!.data.site)
            rightSection = beachLine.insertSuccessor(successorNode: newSection, successorData: copy)
        
            //grab the projection of this site onto the parabola
            let y = ParabolaMath.evalParabola(focusX: leftSection!.data.site.x, focusY: leftSection!.data.site.y, directrix: directrix, x: x)
            let intersection = VPoint(x: x, y: y)
        
            //create the two half edges corresponding to this intersection
            let leftEdge = VEdge(start: intersection, left: site, right: leftSection!.data.site)
            let rightEdge = VEdge(start: intersection, left: leftSection!.data.site, right: site)
            leftEdge.neighbor = rightEdge
        
            //put the edge in the list
            edges.addFirst(leftEdge)
        
            //store the left edge on each arc section
            newSection.data.edge = leftEdge
            rightSection?.data.edge = rightEdge
        
            //store neighbors for delaunay
            leftSection?.data.site.neighbors.append(newSection.data.site)
            newSection.data.site.neighbors.append(leftSection!.data.site)
        
            //create circle events
            BeachLine.checkCircle(section: leftSection!, eventQueue: eventQueue)
            BeachLine.checkCircle(section: rightSection!, eventQueue: eventQueue)
        }
    
        //site is the last beach section on the beach line
        //this can only happen if all previous sites
        //had the same y value
        else if leftSection != nil && rightSection == nil {
            //let minValue = -1.7976931348623157E+308
            let minValue = -Double.greatestFiniteMagnitude
            let start = VPoint(x: (leftSection!.data.site.x + site.x) * 0.5, y: minValue)
            let infEdge = VEdge(start: start, left: leftSection!.data.site, right: site)
            let newEdge = VEdge(start: start, left: site, right: leftSection!.data.site)
        
            newEdge.neighbor = infEdge
            edges.addFirst(newEdge)
        
            leftSection?.data.site.neighbors.append(newSection.data.site)
            newSection.data.site.neighbors.append(leftSection!.data.site)
        
            newSection.data.edge = newEdge
        
            //cant check circles since they are colinear
        }
    
        //site is directly above a break point
        else if leftSection != nil && leftSection !== rightSection {
            //remove false alarms
            if leftSection!.data.circleEvent != nil {
                deleted.add(leftSection!.data.circleEvent!)
                leftSection!.data.circleEvent = nil
            }
    
            if rightSection?.data.circleEvent != nil {
                deleted.add(rightSection!.data.circleEvent!)
                rightSection!.data.circleEvent = nil
            }
    
            //the breakpoint will dissapear if we add this site
            //which means we will create an edge
            //we treat this very similar to a circle event since
            //an edge is finishing at the center of the circle
            //created by circumscribing the left center and right
            //sites
        
            //bring a to the origin
            let leftSite = leftSection!.data.site
            let ax = leftSite.x
            let ay = leftSite.y
            let bx = site.x - ax
            let by = site.y - ay
        
            let rightSite = rightSection!.data.site
            let cx = rightSite.x - ax
            let cy = rightSite.y - ay
            let d = bx*cy - by*cx
            let magnitudeB = bx*bx + by*by
            let magnitudeC = cx*cx + cy*cy
            let vx = (cy*magnitudeB - by * magnitudeC)/(2*d) + ax
            let vy = (bx*magnitudeC - cx * magnitudeB)/(2*d) + ay
            
            let vertex = VPoint(x: vx, y: vy)
        
            rightSection!.data.edge?.end = vertex
        
            //next we create a two new edges
            newSection.data.edge = VEdge(start: vertex, left: site, right: leftSection!.data.site)
            rightSection?.data.edge = VEdge(start: vertex, left: rightSection!.data.site, right: site)
            
            edges.addFirst(newSection.data.edge!)
            edges.addFirst(rightSection!.data.edge!)
        
            //add neighbors for delaunay
            newSection.data.site.neighbors.append(leftSection!.data.site)
            leftSection!.data.site.neighbors.append(newSection.data.site)
        
            newSection.data.site.neighbors.append(rightSection!.data.site)
            rightSection!.data.site.neighbors.append(newSection.data.site)
        
            BeachLine.checkCircle(section: leftSection!, eventQueue: eventQueue)
            BeachLine.checkCircle(section: rightSection!, eventQueue: eventQueue)
        }
    }
    
    func removeBeachSection(circle: FortuneCircleEvent, eventQueue: MinHeap<FortuneEvent>, deleted: HashSet<FortuneCircleEvent>, edges: LinkedList<VEdge>) {
        let section = circle.toDelete
        let x = circle.x
        let y = circle.yCenter
        let vertex = VPoint(x: x, y: y)
    
        //multiple edges could end here
        var toBeRemoved = Array<RBTreeNode<BeachSection>>()
    
        //look left
        var prev = section.previous!
        while prev.data.circleEvent != nil &&
        ParabolaMath.approxEqual(x - prev.data.circleEvent!.x, 0) &&
        ParabolaMath.approxEqual(y - prev.data.circleEvent!.y, 0) {
            toBeRemoved.append(prev)
            prev = prev.previous!
        }
    
        var next = section.next!
        while next.data.circleEvent != nil &&
        ParabolaMath.approxEqual(x - next.data.circleEvent!.x, 0) &&
        ParabolaMath.approxEqual(y - next.data.circleEvent!.y, 0) {
            toBeRemoved.append(next)
            next = next.next!
        }
    
        section.data.edge?.end = vertex
        section.next?.data.edge?.end = vertex
        section.data.circleEvent = nil
    
        //odds are this double writes a few edges but this is clean...
        for remove in toBeRemoved {
            remove.data.edge?.end = vertex
            remove.next?.data.edge?.end = vertex
            deleted.add(remove.data.circleEvent!)
            remove.data.circleEvent = nil
        }
    
        //need to delete all upcoming circle events with this node
        if prev.data.circleEvent != nil {
            deleted.add(prev.data.circleEvent!)
            prev.data.circleEvent = nil
        }
        if next.data.circleEvent != nil {
            deleted.add(next.data.circleEvent!)
            next.data.circleEvent = nil
        }
    
        //create a new edge with start point at the vertex and assign it to next
        let newEdge = VEdge(start: vertex, left: next.data.site, right: prev.data.site)
        next.data.edge = newEdge
        edges.addFirst(newEdge)
    
        //add neighbors for delaunay
        prev.data.site.neighbors.append(next.data.site)
        next.data.site.neighbors.append(prev.data.site)
    
        //remove the sectionfrom the tree
        beachLine.removeNode(section)
        for remove in toBeRemoved {
            beachLine.removeNode(remove)
        }
    
        BeachLine.checkCircle(section: prev, eventQueue: eventQueue)
        BeachLine.checkCircle(section: next, eventQueue: eventQueue)
    }
    
    private static func leftBreakpoint(node: RBTreeNode<BeachSection>, directrix: Double) -> Double {
        let leftNode = node.previous
        //degenerate parabola
        if ParabolaMath.approxEqual(node.data.site.y - directrix, 0) {
            return node.data.site.x
        }
        //node is the first piece of the beach line
        if leftNode == nil {
            return -Double.infinity
        }
        //left node is degenerate
        if ParabolaMath.approxEqual(leftNode!.data.site.y - directrix, 0) {
            return leftNode!.data.site.x
        }
        let site = node.data.site
        let leftSite = leftNode!.data.site
        return ParabolaMath.intersectParabolaX(focus1X: leftSite.x, focus1Y: leftSite.y, focus2X: site.x, focus2Y: site.y, directrix: directrix)
    }
    
    private static func rightBreakpoint(node: RBTreeNode<BeachSection>, directrix: Double) -> Double {
        let rightNode = node.next
        //degenerate parabola
        if ParabolaMath.approxEqual(node.data.site.y - directrix, 0) {
            return node.data.site.x
        }
        //node is the last piece of the beach line
        if rightNode == nil {
            return Double.infinity
        }
        //left node is degenerate
        if ParabolaMath.approxEqual(rightNode!.data.site.y - directrix, 0) {
            return rightNode!.data.site.x
        }
        let site = node.data.site
        let rightSite = rightNode!.data.site
        return ParabolaMath.intersectParabolaX(focus1X: site.x, focus1Y: site.y, focus2X: rightSite.x, focus2Y: rightSite.y, directrix: directrix)
    }
    
    private static func checkCircle(section: RBTreeNode<BeachSection>, eventQueue: MinHeap<FortuneEvent>) {
        //if (section == nil)
        //    return
        let left = section.previous
        let right = section.next
        if left == nil || right == nil {
            return
        }
    
        let leftSite = left!.data.site
        let centerSite = section.data.site
        let rightSite = right!.data.site
    
        //if the left arc and right arc are defined by the same
        //focus, the two arcs cannot converge
        if leftSite === rightSite {
            return
        }
    
        // http://mathforum.org/library/drmath/view/55002.html
        // because every piece of this program needs to be demoed in maple >.<
    
        //MATH HACKS: place center at origin and
        //draw vectors a and c to
        //left and right respectively
        let bx = centerSite.x,
        by = centerSite.y,
        ax = leftSite.x - bx,
        ay = leftSite.y - by,
        cx = rightSite.x - bx,
        cy = rightSite.y - by
    
        //The center beach section can only dissapear when
        //the angle between a and c is negative
        let d = ax*cy - ay*cx
        if ParabolaMath.approxGreaterThanOrEqualTo(d, 0) {
            return
        }
    
        let magnitudeA = ax*ax + ay*ay
        let magnitudeC = cx*cx + cy*cy
        let x = (cy*magnitudeA - ay*magnitudeC)/(2*d)
        let y = (ax*magnitudeC - cx*magnitudeA)/(2*d)
    
        //add back offset
        let ycenter = y + by
        //y center is off
        let circleEvent = FortuneCircleEvent(
            lowest: VPoint(x: x + bx, y: ycenter + sqrt(x * x + y * y)),
            yCenter: ycenter,
            toDelete: section
        )
        section.data.circleEvent = circleEvent
        let _ = eventQueue.insert(circleEvent)
    }
}