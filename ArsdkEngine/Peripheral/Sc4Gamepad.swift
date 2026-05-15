// Copyright (C) 2021 Parrot Drones SAS
//
//    Redistribution and use in source and binary forms, with or without
//    modification, are permitted provided that the following conditions
//    are met:
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above copyright
//      notice, this list of conditions and the following disclaimer in
//      the documentation and/or other materials provided with the
//      distribution.
//    * Neither the name of the Parrot Company nor the names
//      of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written
//      permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//    PARROT COMPANY BE LIABLE FOR ANY DIRECT, INDIRECT,
//    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
//    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

import Foundation
import GroundSdk

/// Gamepad controller for SkyController 4
class Sc4Gamepad: MapperVirtualGamepad {
    /// SkyCtrl4Gamepad component
    private var skyCtrl4Gamepad: SkyCtrl4GamepadCore!

    private var buttonsMappings = [UInt: SkyCtrl4ButtonsMappingEntry]()

    private var axisMappings = [UInt: SkyCtrl4AxisMappingEntry]()

    private var axisInterpolators: [UInt: SkyCtrl4GamepadCore.AxisInterpolatorEntry] = [:]

    private var reversedAxes: [UInt: SkyCtrl4GamepadCore.ReversedAxisEntry] = [:]

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        specializedBackend = self
        skyCtrl4Gamepad = SkyCtrl4GamepadCore(store: deviceController.device.peripheralStore, backend: self)
    }

    /// Drone is connected
    override func didConnect() {
        super.didConnect()
        skyCtrl4Gamepad.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        super.didDisconnect()
        skyCtrl4Gamepad.resetEventListeners()
        skyCtrl4Gamepad.unpublish()
    }
}

/// Extension of Sc4Gamepad that implements SkyCtrl4GamepadBackend
extension Sc4Gamepad: SkyCtrl4GamepadBackend {
    public func grab(buttons: Set<SkyCtrl4Button>, axes: Set<SkyCtrl4Axis>) {
        let mask = Sc4InputTranslator.convert(buttons: buttons, axes: axes)
        grab(buttonsMask: mask.buttonsMask, axesMask: mask.axesMask)
    }

    func setup(mappingEntry: SkyCtrl4MappingEntry, register: Bool) {
        switch mappingEntry.type {
        case .buttons:
            let buttonsEntry = mappingEntry as! SkyCtrl4ButtonsMappingEntry
            if register {
                let buttonMask = Sc4Buttons.maskFrom(buttonEvents: buttonsEntry.buttonEvents)
                sendAddButtonsMappingEntry(droneModel: mappingEntry.droneModel, action: buttonsEntry.action,
                                           buttonsMask: buttonMask)
            } else {
                sendRemoveButtonsMappingEntry(droneModel: mappingEntry.droneModel, action: buttonsEntry.action)
            }

        case .axis:
            let axisEntry = mappingEntry as! SkyCtrl4AxisMappingEntry
            if register {
                let axis = Sc4Axes.convert(axisEntry.axisEvent)!
                let buttonMask = Sc4Buttons.maskFrom(buttonEvents: axisEntry.buttonEvents)
                sendAddAxisMappingEntry(droneModel: mappingEntry.droneModel, action: axisEntry.action, axis: axis,
                                        buttonsMask: buttonMask)
            } else {
                sendRemoveAxisMappingEntry(droneModel: mappingEntry.droneModel, action: axisEntry.action)
            }
        }
    }

    func resetMapping(forModel model: Drone.Model?) {
        sendResetMapping(forModel: model)
    }

    public func set(
        interpolator: AxisInterpolator, forDroneModel droneModel: Drone.Model, onAxis axis: SkyCtrl4Axis) {

            if let mapperAxis = Sc4Axes.convert(axis) {
                send(interpolator: interpolator, forDroneModel: droneModel, onAxis: mapperAxis)
            }
        }

    public func set(axis: SkyCtrl4Axis, forDroneModel droneModel: Drone.Model, reversed: Bool) {
        if let mapperAxis = Sc4Axes.convert(axis) {
            send(axis: mapperAxis, forDroneModel: droneModel, reversed: reversed)
        }
    }

    public func set(volatileMapping: Bool) -> Bool {
        send(volatileMapping: volatileMapping)
        return true
    }
}

/// Extension of Sc4Gamepad that implements SpecializedGamepadBackend
extension Sc4Gamepad: SpecializedGamepadBackend {
    /// The buttons mask of all navigation buttons
    var navigationGrabButtonsMask: MapperButtonsMask {
        return MapperButtonsMask.from(.button2, .button3, .button4, .button5, .button6, .button7)
    }

    /// The axes mask of all navigation axes
    var navigationGrabAxesMask: MapperAxesMask {
        return MapperAxesMask.from(.axis0, .axis1)
    }

    /// Translate a button mask into a gamepad event
    ///
    /// - Parameter mask: the mask of buttons to translate
    /// - returns: a navigation event if the mask is related to navigation
    func eventFrom(button: MapperButton) -> VirtualGamepadEvent? {
        switch button {
        case .button4:
            return .left
        case .button5:
            return .right
        case .button6:
            return .up
        case .button7:
            return .down
        case .button3:
            return .cancel
        case .button2:
            return .ok
        default:
            return nil
        }
    }

    /// Updates the grab state
    ///
    /// - Parameters:
    ///     - buttonsMask: mask of all grabbed buttons
    ///     - axesMask: mask of all grabbed axes
    ///     - pressedButtons: mask of all pressed buttons
    func updateGrabState(buttonsMask: MapperButtonsMask, axesMask: MapperAxesMask, pressedButtons: MapperButtonsMask) {
        var grabbedButtons = Set<SkyCtrl4Button>()
        var grabbedAxes = Set<SkyCtrl4Axis>()
        // check for all buttons if some are grabbed
        for button in SkyCtrl4Button.allCases {
            let buttonsMaskUsedByButton = Sc4InputTranslator.convert(button: button)
            if buttonsMask.intersection(buttonsMaskUsedByButton) != .none {
                grabbedButtons.insert(button)

                if !buttonsMask.contains(buttonsMaskUsedByButton) {
                    ULog.w(.mapperTag, "Missing grabbed buttons for button \(button.description)." +
                           "\(buttonsMaskUsedByButton.rawValue) is not fully contained in: \(buttonsMask.rawValue)")
                }
            }
        }
        // check for all axes if some buttons or axes are grabbed
        for axis in SkyCtrl4Axis.allCases {
            let mask = Sc4InputTranslator.convert(axis: axis)
            let buttonsMaskUsedByAxis = mask.buttonsMask
            let axesMaskUsedByAxis = mask.axesMask
            if buttonsMask.intersection(buttonsMaskUsedByAxis) != .none {
                grabbedAxes.insert(axis)

                if !buttonsMask.contains(buttonsMaskUsedByAxis) {
                    ULog.w(.mapperTag, "Missing grabbed buttons for axis \(axis.description)." +
                           "\(buttonsMaskUsedByAxis.rawValue) is not fully contained in: \(buttonsMask.rawValue)")
                }
            }
            if axesMask.intersection(axesMaskUsedByAxis) != .none {
                grabbedAxes.insert(axis)

                if !axesMask.contains(axesMaskUsedByAxis) {
                    ULog.w(.mapperTag, "Missing grabbed axes for axis \(axis.description)." +
                           "\(axesMaskUsedByAxis.rawValue) is not fully contained in: \(axesMask.rawValue)")
                }
            }
        }
        skyCtrl4Gamepad.updateGrabbedButtons(grabbedButtons)
            .updateGrabbedAxes(grabbedAxes)
            .updateButtonEventStates(Sc4Buttons.statesFrom(buttons: buttonsMask, pressedButtons: pressedButtons))
            .notifyUpdated()
    }

    /// Updates the states of the given button
    ///
    /// - Parameters:
    ///     - buttonMask: the button mask that triggered the event
    ///     - event: the event triggered
    func updateButtonEventState(button: MapperButton, event: ArsdkFeatureMapperButtonEvent) {
        let buttonEvent = Sc4Buttons.buttonEvents[button]
        if let buttonEvent = buttonEvent {
            let state: SkyCtrl4ButtonEventState
            switch event {
            case .press:
                state = .pressed
            case .release:
                state = .released
            case .sdkCoreUnknown:
                fallthrough
            @unknown default:
                // don't change anything if value is unknown
                ULog.w(.tag, "Unknown button event type, skipping this event.")
                return
            }
            skyCtrl4Gamepad.updateButtonEventState(buttonEvent, state: state).notifyUpdated()
        }
    }

    /// Updates the value of the given axis
    ///
    /// - Parameters:
    ///     - axis: the axis that triggered the value change
    ///     - value: the current axis value
    func updateAxisEventValue(axis: MapperAxis, value: Int) {
        let axisEvent: SkyCtrl4AxisEvent? = Sc4Axes.convert(axis)
        if let axisEvent = axisEvent {
            skyCtrl4Gamepad.updateAxisEventValue(axisEvent, value: value)
        }
    }

    func clearAllButtonsMappings() {
        buttonsMappings.removeAll()
    }

    func removeButtonsMappingEntry(withUid uid: UInt) {
        buttonsMappings[uid] = nil
    }

    func addButtonsMappingEntry(
        uid: UInt, droneModel: Drone.Model, action: ButtonsMappableAction, buttons: MapperButtonsMask) {
            let buttonEvents = Sc4Buttons.eventsFrom(buttons: buttons)
            if !buttonEvents.isEmpty {
                buttonsMappings[uid] = SkyCtrl4ButtonsMappingEntry(droneModel: droneModel, action: action,
                                                                   buttonEvents: buttonEvents)
            } else {
                ULog.w(.mapperTag, "Invalid event \(buttons), dropping mapping [uid: \(uid) model: \(droneModel)" +
                       " action: \(action)")
            }
        }

    func updateButtonsMappings() {
        skyCtrl4Gamepad.updateButtonsMappings(Array(buttonsMappings.values)).notifyUpdated()
    }

    func clearAllAxisMappings() {
        axisMappings.removeAll()
    }

    func removeAxisMappingEntry(withUid uid: UInt) {
        axisMappings[uid] = nil
    }

    func addAxisMappingEntry(
        uid: UInt, droneModel: Drone.Model, action: AxisMappableAction, axis: MapperAxis,
        buttons: MapperButtonsMask) {
            let axisEvent: SkyCtrl4AxisEvent? = Sc4Axes.convert(axis)
            let buttonEvents = Sc4Buttons.eventsFrom(buttons: buttons)
            if let axisEvent = axisEvent {
                axisMappings[uid] = SkyCtrl4AxisMappingEntry(droneModel: droneModel,
                                                             action: action,
                                                             axisEvent: axisEvent,
                                                             buttonEvents: buttonEvents)
            } else {
                ULog.w(.mapperTag, "Invalid axis event \(axis.rawValue), dropping mapping [uid: \(uid) " +
                       " model: \(droneModel) action: \(action)")
            }
        }

    func updateAxisMappings() {
        skyCtrl4Gamepad.updateAxisMappings(Array(axisMappings.values)).notifyUpdated()
    }

    func updateActiveDroneModel(_ droneModel: Drone.Model) {
        skyCtrl4Gamepad.updateActiveDroneModel(droneModel).notifyUpdated()
    }

    func update(volatileMapping: Bool) {
        skyCtrl4Gamepad.update(volatileMappingState: volatileMapping)
    }

    func clearAllAxisInterpolators() {
        axisInterpolators.removeAll()
    }

    func removeAxisInterpolator(withUid uid: UInt) {
        axisInterpolators[uid] = nil
    }

    func addAxisInterpolator(
        uid: UInt, droneModel: Drone.Model, axis: MapperAxis, interpolator: AxisInterpolator) {
            if let sc4Axis: SkyCtrl4Axis = Sc4Axes.convert(axis) {
                axisInterpolators[uid] = SkyCtrl4GamepadCore.AxisInterpolatorEntry(
                    droneModel: droneModel, axis: sc4Axis, interpolator: interpolator)
            }
        }

    func updateAxisInterpolators() {
        // axis interpolators also serve to provide the set of supported drone models
        var supportedDroneModels: Set<Drone.Model> = []
        axisInterpolators.values.forEach { interpolatorEntry in
            supportedDroneModels.insert(interpolatorEntry.droneModel)
        }

        skyCtrl4Gamepad.updateSupportedDroneModels(supportedDroneModels)
            .updateAxisInterpolators(Array(axisInterpolators.values))
            .notifyUpdated()
    }

    func clearAllReversedAxes() {
        reversedAxes.removeAll()
    }

    func removeReversedAxis(withUid uid: UInt) {
        reversedAxes[uid] = nil
    }

    func addReversedAxis(uid: UInt, droneModel: Drone.Model, axis: MapperAxis, reversed: Bool) {
        if let sc4Axis: SkyCtrl4Axis = Sc4Axes.convert(axis) {
            reversedAxes[uid] = SkyCtrl4GamepadCore.ReversedAxisEntry(
                droneModel: droneModel, axis: sc4Axis, reversed: reversed)
        }
    }

    func updateReversedAxis() {
        skyCtrl4Gamepad.updateReversedAxes(Array(reversedAxes.values)).notifyUpdated()
    }
}
