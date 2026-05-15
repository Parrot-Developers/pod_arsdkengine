// Copyright (C) 2024 Parrot Drones SAS
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

/// Gamepad controller for SkyController UA2
class ScUa2Gamepad: MapperVirtualGamepad {
    /// SkyCtrlUa2Gamepad component
    private var skyCtrlUa2Gamepad: SkyCtrlUa2GamepadCore!

    private var buttonsMappings = [UInt: SkyCtrlUa2ButtonsMappingEntry]()

    private var axisMappings = [UInt: SkyCtrlUa2AxisMappingEntry]()

    private var axisInterpolators: [UInt: SkyCtrlUa2GamepadCore.AxisInterpolatorEntry] = [:]

    private var reversedAxes: [UInt: SkyCtrlUa2GamepadCore.ReversedAxisEntry] = [:]

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        specializedBackend = self
        skyCtrlUa2Gamepad = SkyCtrlUa2GamepadCore(store: deviceController.device.peripheralStore, backend: self)
    }

    /// Drone is connected
    override func didConnect() {
        // no super call to prevent VirtualGamepad publishing
        skyCtrlUa2Gamepad.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        skyCtrlUa2Gamepad.resetEventListeners()
        skyCtrlUa2Gamepad.unpublish()
    }
}

/// Extension of ScUa2Gamepad that implements SkyCtrlUa2GamepadBackend
extension ScUa2Gamepad: SkyCtrlUa2GamepadBackend {
    public func grab(buttons: Set<SkyCtrlUa2Button>, axes: Set<SkyCtrlUa2Axis>) {
        let mask = ScUa2InputTranslator.convert(buttons: buttons, axes: axes)
        grab(buttonsMask: mask.buttonsMask, axesMask: mask.axesMask)
    }

    func setup(mappingEntry: SkyCtrlUa2MappingEntry, register: Bool) {
        switch mappingEntry.type {
        case .buttons:
            let buttonsEntry = mappingEntry as! SkyCtrlUa2ButtonsMappingEntry
            if register {
                let buttonMask = ScUa2Buttons.maskFrom(buttonEvents: buttonsEntry.buttonEvents)
                sendAddButtonsMappingEntry(droneModel: mappingEntry.droneModel, action: buttonsEntry.action,
                                           buttonsMask: buttonMask)
            } else {
                sendRemoveButtonsMappingEntry(droneModel: mappingEntry.droneModel, action: buttonsEntry.action)
            }

        case .axis:
            let axisEntry = mappingEntry as! SkyCtrlUa2AxisMappingEntry
            if register {
                let axis = ScUa2Axes.convert(axisEntry.axisEvent)!
                let buttonMask = ScUa2Buttons.maskFrom(buttonEvents: axisEntry.buttonEvents)
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
        interpolator: AxisInterpolator, forDroneModel droneModel: Drone.Model, onAxis axis: SkyCtrlUa2Axis) {

            if let mapperAxis = ScUa2Axes.convert(axis) {
                send(interpolator: interpolator, forDroneModel: droneModel, onAxis: mapperAxis)
            }
        }

    public func set(axis: SkyCtrlUa2Axis, forDroneModel droneModel: Drone.Model, reversed: Bool) {
        if let mapperAxis = ScUa2Axes.convert(axis) {
            send(axis: mapperAxis, forDroneModel: droneModel, reversed: reversed)
        }
    }

    public func set(volatileMapping: Bool) -> Bool {
        send(volatileMapping: volatileMapping)
        return true
    }
}

/// Extension of ScUa2Gamepad that implements SpecializedGamepadBackend
extension ScUa2Gamepad: SpecializedGamepadBackend {
    /// The buttons mask of all navigation buttons
    var navigationGrabButtonsMask: MapperButtonsMask {
        return MapperButtonsMask.none
    }

    /// The axes mask of all navigation axes
    var navigationGrabAxesMask: MapperAxesMask {
        return MapperAxesMask.none
    }

    /// Translate a button mask into a gamepad event
    ///
    /// - Parameter mask: the mask of buttons to translate
    /// - returns: a navigation event if the mask is related to navigation
    func eventFrom(button: MapperButton) -> VirtualGamepadEvent? {
        return nil
    }

    /// Updates the grab state
    ///
    /// - Parameters:
    ///     - buttonsMask: mask of all grabbed buttons
    ///     - axesMask: mask of all grabbed axes
    ///     - pressedButtons: mask of all pressed buttons
    func updateGrabState(buttonsMask: MapperButtonsMask, axesMask: MapperAxesMask, pressedButtons: MapperButtonsMask) {
        var grabbedButtons = Set<SkyCtrlUa2Button>()
        var grabbedAxes = Set<SkyCtrlUa2Axis>()
        // check for all buttons if some are grabbed
        for button in SkyCtrlUa2Button.allCases {
            let buttonsMaskUsedByButton = ScUa2InputTranslator.convert(button: button)
            if buttonsMask.intersection(buttonsMaskUsedByButton) != .none {
                grabbedButtons.insert(button)

                if !buttonsMask.contains(buttonsMaskUsedByButton) {
                    ULog.w(.mapperTag, "Missing grabbed buttons for button \(button.description)." +
                           "\(buttonsMaskUsedByButton.rawValue) is not fully contained in: \(buttonsMask.rawValue)")
                }
            }
        }
        // check for all axes if some buttons or axes are grabbed
        for axis in SkyCtrlUa2Axis.allCases {
            let mask = ScUa2InputTranslator.convert(axis: axis)
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
        skyCtrlUa2Gamepad.updateGrabbedButtons(grabbedButtons)
            .updateGrabbedAxes(grabbedAxes)
            .updateButtonEventStates(ScUa2Buttons.statesFrom(buttons: buttonsMask, pressedButtons: pressedButtons))
            .notifyUpdated()
    }

    /// Updates the states of the given button
    ///
    /// - Parameters:
    ///     - buttonMask: the button mask that triggered the event
    ///     - event: the event triggered
    func updateButtonEventState(button: MapperButton, event: ArsdkFeatureMapperButtonEvent) {
        let buttonEvent = ScUa2Buttons.buttonEvents[button]
        if let buttonEvent = buttonEvent {
            let state: SkyCtrlUa2ButtonEventState
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
            skyCtrlUa2Gamepad.updateButtonEventState(buttonEvent, state: state).notifyUpdated()
        }
    }

    /// Updates the value of the given axis
    ///
    /// - Parameters:
    ///     - axis: the axis that triggered the value change
    ///     - value: the current axis value
    func updateAxisEventValue(axis: MapperAxis, value: Int) {
        let axisEvent: SkyCtrlUa2AxisEvent? = ScUa2Axes.convert(axis)
        if let axisEvent = axisEvent {
            skyCtrlUa2Gamepad.updateAxisEventValue(axisEvent, value: value)
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
            let buttonEvents = ScUa2Buttons.eventsFrom(buttons: buttons)
            if !buttonEvents.isEmpty {
                buttonsMappings[uid] = SkyCtrlUa2ButtonsMappingEntry(droneModel: droneModel, action: action,
                                                                   buttonEvents: buttonEvents)
            } else {
                ULog.w(.mapperTag, "Invalid event \(buttons), dropping mapping [uid: \(uid) model: \(droneModel)" +
                       " action: \(action)")
            }
        }

    func updateButtonsMappings() {
        skyCtrlUa2Gamepad.updateButtonsMappings(Array(buttonsMappings.values)).notifyUpdated()
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
            let axisEvent: SkyCtrlUa2AxisEvent? = ScUa2Axes.convert(axis)
            let buttonEvents = ScUa2Buttons.eventsFrom(buttons: buttons)
            if let axisEvent = axisEvent {
                axisMappings[uid] = SkyCtrlUa2AxisMappingEntry(droneModel: droneModel,
                                                             action: action,
                                                             axisEvent: axisEvent,
                                                             buttonEvents: buttonEvents)
            } else {
                ULog.w(.mapperTag, "Invalid axis event \(axis.rawValue), dropping mapping [uid: \(uid) " +
                       " model: \(droneModel) action: \(action)")
            }
        }

    func updateAxisMappings() {
        skyCtrlUa2Gamepad.updateAxisMappings(Array(axisMappings.values)).notifyUpdated()
    }

    func updateActiveDroneModel(_ droneModel: Drone.Model) {
        skyCtrlUa2Gamepad.updateActiveDroneModel(droneModel).notifyUpdated()
    }

    func update(volatileMapping: Bool) {
        skyCtrlUa2Gamepad.update(volatileMappingState: volatileMapping)
    }

    func clearAllAxisInterpolators() {
        axisInterpolators.removeAll()
    }

    func removeAxisInterpolator(withUid uid: UInt) {
        axisInterpolators[uid] = nil
    }

    func addAxisInterpolator(
        uid: UInt, droneModel: Drone.Model, axis: MapperAxis, interpolator: AxisInterpolator) {
            if let scUa2Axis: SkyCtrlUa2Axis = ScUa2Axes.convert(axis) {
                axisInterpolators[uid] = SkyCtrlUa2GamepadCore.AxisInterpolatorEntry(
                    droneModel: droneModel, axis: scUa2Axis, interpolator: interpolator)
            }
        }

    func updateAxisInterpolators() {
        // axis interpolators also serve to provide the set of supported drone models
        var supportedDroneModels: Set<Drone.Model> = []
        axisInterpolators.values.forEach { interpolatorEntry in
            supportedDroneModels.insert(interpolatorEntry.droneModel)
        }

        skyCtrlUa2Gamepad.updateSupportedDroneModels(supportedDroneModels)
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
        if let scUa2Axis: SkyCtrlUa2Axis = ScUa2Axes.convert(axis) {
            reversedAxes[uid] = SkyCtrlUa2GamepadCore.ReversedAxisEntry(
                droneModel: droneModel, axis: scUa2Axis, reversed: reversed)
        }
    }

    func updateReversedAxis() {
        skyCtrlUa2Gamepad.updateReversedAxes(Array(reversedAxes.values)).notifyUpdated()
    }
}
