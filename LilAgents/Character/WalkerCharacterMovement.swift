import AppKit

extension WalkerCharacter {
    func startWalk() {
        isPaused = false
        isWalking = true
        walkStartTime = CACurrentMediaTime()

        if positionProgress > 0.85 {
            goingRight = false
        } else if positionProgress < 0.15 {
            goingRight = true
        } else {
            goingRight = Bool.random()
        }

        walkStartPos = positionProgress
        let referenceWidth: CGFloat = 500.0
        let walkPixels = CGFloat.random(in: walkAmountRange) * referenceWidth
        let walkAmount = currentTravelDistance > 0 ? walkPixels / currentTravelDistance : 0.3
        if goingRight {
            walkEndPos = min(walkStartPos + walkAmount, 1.0)
        } else {
            walkEndPos = max(walkStartPos - walkAmount, 0.0)
        }
        walkStartPixel = walkStartPos * currentTravelDistance
        walkEndPixel = walkEndPos * currentTravelDistance

        let minSeparation: CGFloat = 0.12
        if let siblings = controller?.characters {
            for sibling in siblings where sibling !== self {
                let sibPos = sibling.positionProgress
                if abs(walkEndPos - sibPos) < minSeparation {
                    if goingRight {
                        walkEndPos = max(walkStartPos, sibPos - minSeparation)
                    } else {
                        walkEndPos = min(walkStartPos, sibPos + minSeparation)
                    }
                }
            }
        }

        setFacing(goingRight ? .right : .left)
    }

    func enterPause() {
        isWalking = false
        isPaused = true
        setFacing(.front)
        let delay = Double.random(in: 5.0...12.0)
        pauseEndTime = CACurrentMediaTime() + delay
    }

    func movementPosition(at videoTime: CFTimeInterval) -> CGFloat {
        let dIn = fullSpeedStart - accelStart
        let dLin = decelStart - fullSpeedStart
        let dOut = walkStop - decelStart
        let v = 1.0 / (dIn / 2.0 + dLin + dOut / 2.0)

        if videoTime <= accelStart {
            return 0.0
        } else if videoTime <= fullSpeedStart {
            let t = videoTime - accelStart
            return CGFloat(v * t * t / (2.0 * dIn))
        } else if videoTime <= decelStart {
            let easeInDist = v * dIn / 2.0
            let t = videoTime - fullSpeedStart
            return CGFloat(easeInDist + v * t)
        } else if videoTime <= walkStop {
            let easeInDist = v * dIn / 2.0
            let linearDist = v * dLin
            let t = videoTime - decelStart
            return CGFloat(easeInDist + linearDist + v * (t - t * t / (2.0 * dOut)))
        } else {
            return 1.0
        }
    }

    func update(dockX: CGFloat, dockWidth: CGFloat, dockTopY: CGFloat) {
        currentTravelDistance = max(dockWidth - displayWidth, 0)
        if isCompanionAvatar {
            let travelDistance = currentTravelDistance
            let x = dockX + travelDistance * positionProgress + flipXOffset
            let bottomPadding = displayHeight * 0.15
            let y = dockTopY - bottomPadding + yOffset
            window.setFrameOrigin(NSPoint(x: x, y: y))
            hideBubble()
            updateExpertNameTag()
            return
        }
        if isIdleForPopover {
            let travelDistance = currentTravelDistance
            let x = dockX + travelDistance * positionProgress + flipXOffset
            let bottomPadding = displayHeight * 0.15
            let y = dockTopY - bottomPadding + yOffset
            window.setFrameOrigin(NSPoint(x: x, y: y))
            updatePopoverPosition()
            updateThinkingBubble()
            updateExpertNameTag()
            return
        }

        let now = CACurrentMediaTime()

        if isPaused {
            if now >= pauseEndTime {
                startWalk()
            } else {
                let travelDistance = max(dockWidth - displayWidth, 0)
                let x = dockX + travelDistance * positionProgress + flipXOffset
                let bottomPadding = displayHeight * 0.15
                let y = dockTopY - bottomPadding + yOffset
                window.setFrameOrigin(NSPoint(x: x, y: y))
                updateExpertNameTag()
                return
            }
        }

        if isWalking {
            let elapsed = now - walkStartTime
            let videoTime = min(elapsed, 10.0)
            let travelDistance = currentTravelDistance

            let walkNorm = elapsed >= 10.0 ? 1.0 : movementPosition(at: videoTime)
            let currentPixel = walkStartPixel + (walkEndPixel - walkStartPixel) * walkNorm

            if travelDistance > 0 {
                positionProgress = min(max(currentPixel / travelDistance, 0), 1)
            }

            if elapsed >= 10.0 {
                walkEndPos = positionProgress
                enterPause()
                return
            }

            let x = dockX + travelDistance * positionProgress + flipXOffset
            let bottomPadding = displayHeight * 0.15
            let y = dockTopY - bottomPadding + yOffset
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        updateThinkingBubble()
        updateExpertNameTag()
    }
}
