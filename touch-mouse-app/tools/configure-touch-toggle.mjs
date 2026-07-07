#!/usr/bin/env node
// 根据 remote-settings.json 生成 Karabiner 配置里的“触摸滑动开关按键”规则。

import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const projectDir = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const defaultSettingsPath = path.join(projectDir, 'remote-settings.json');
const defaultConfigPath = path.join(projectDir, 'karabiner-siri-remote-safe.json');
const installedConfigPath = path.join(os.homedir(), '.config/karabiner/karabiner.json');
const toggleSignalPath = '/tmp/SiriRemoteTouchMouse.toggle';
const generatedVariableName = 'siri_remote_touch_toggle_pending';
const legacyVariableNames = new Set([
  generatedVariableName,
  'siri_remote_selection_pending'
]);

const remoteDeviceCondition = {
  identifiers: [
    {
      is_consumer: true,
      product_id: 789,
      vendor_id: 76
    }
  ],
  type: 'device_if'
};

const buttonCatalog = {
  selection: {
    label: '确认键',
    from: { consumer_key_code: 'selection' },
    singleAction: [{ key_code: 'return_or_enter' }]
  },
  back: {
    label: '返回键',
    from: { generic_desktop: 'system_app_menu' },
    singleAction: [{ pointing_button: 'button1' }, { key_code: 'return_or_enter' }]
  },
  home: {
    label: 'Home 键',
    from: { consumer_key_code: 'data_on_screen' },
    singleAction: [{ pointing_button: 'button2' }]
  },
  mute: {
    label: '静音键',
    from: { consumer_key_code: 'mute' },
    singleAction: [{ key_code: 'delete_or_backspace' }],
    holdAction: [
      { key_code: 'a', modifiers: ['left_command'] },
      { key_code: 'delete_or_backspace' }
    ]
  },
  play_pause: {
    label: '播放/暂停键',
    from: { consumer_key_code: 'play_or_pause' },
    singleAction: [{ key_code: 'spacebar' }]
  },
  microphone: {
    label: '麦克风键',
    from: { consumer_key_code: 'microphone' },
    singleAction: [{ apple_vendor_top_case_key_code: 'keyboard_fn' }]
  }
};

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function writeJson(filePath, value) {
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 4)}\n`);
}

function normalizeSettings(settings) {
  const button = settings.touchMouseToggleButton ?? 'selection';
  if (!buttonCatalog[button]) {
    throw new Error(`未知按键：${button}。可选：${Object.keys(buttonCatalog).join(', ')}`);
  }

  return {
    button,
    doubleClickDelayMilliseconds: Number(settings.doubleClickDelayMilliseconds ?? 300),
    longPressDelayMilliseconds: Number(settings.longPressDelayMilliseconds ?? 500)
  };
}

function hasVariableCondition(manipulator, variableName) {
  return (manipulator.conditions ?? []).some((condition) => condition.name === variableName);
}

function hasToggleShellCommand(manipulator) {
  return (manipulator.to ?? []).some((item) => item.shell_command === `/usr/bin/touch ${toggleSignalPath}`);
}

function isLegacyOrGeneratedToggleManipulator(manipulator) {
  if (hasToggleShellCommand(manipulator)) {
    return true;
  }

  for (const variableName of legacyVariableNames) {
    if (hasVariableCondition(manipulator, variableName)) {
      return true;
    }
  }

  return false;
}

function sameFrom(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function isSelectedButtonManipulator(manipulator, button) {
  return sameFrom(manipulator.from, button.from);
}

function createSinglePressManipulator(buttonName, settings) {
  const button = buttonCatalog[buttonName];
  const manipulator = {
    conditions: [remoteDeviceCondition],
    from: button.from,
    type: 'basic'
  };

  if (button.holdAction) {
    manipulator.parameters = {
      'basic.to_if_held_down_threshold_milliseconds': settings.longPressDelayMilliseconds
    };
    manipulator.to_if_alone = button.singleAction;
    manipulator.to_if_held_down = button.holdAction;
  } else {
    manipulator.to = button.singleAction;
  }

  return manipulator;
}

function createDoubleClickManipulators({ buttonName, variableName, doubleAction, settings }) {
  const button = buttonCatalog[buttonName];
  const pendingIf = {
    name: variableName,
    type: 'variable_if',
    value: 1
  };
  const pendingUnless = {
    name: variableName,
    type: 'variable_unless',
    value: 1
  };
  const clearPending = {
    set_variable: {
      name: variableName,
      value: 0
    }
  };

  return [
    {
      conditions: [remoteDeviceCondition, pendingIf],
      from: button.from,
      to: [
        clearPending,
        ...doubleAction
      ],
      type: 'basic'
    },
    {
      conditions: [remoteDeviceCondition, pendingUnless],
      from: button.from,
      parameters: {
        'basic.to_delayed_action_delay_milliseconds': settings.doubleClickDelayMilliseconds
      },
      to: [
        {
          set_variable: {
            name: variableName,
            value: 1
          }
        }
      ],
      to_delayed_action: {
        to_if_canceled: [clearPending],
        to_if_invoked: [clearPending, ...button.singleAction]
      },
      type: 'basic'
    }
  ];
}

function createBaseManipulators(settings) {
  return [
    createSinglePressManipulator('selection', settings),
    ...createDoubleClickManipulators({
      buttonName: 'back',
      variableName: 'siri_remote_back_pending',
      doubleAction: [{ key_code: 'left_arrow', modifiers: ['left_control'] }],
      settings
    }),
    ...createDoubleClickManipulators({
      buttonName: 'home',
      variableName: 'siri_remote_home_pending',
      doubleAction: [{ key_code: 'right_arrow', modifiers: ['left_control'] }],
      settings
    }),
    createSinglePressManipulator('mute', settings),
    ...createDoubleClickManipulators({
      buttonName: 'play_pause',
      variableName: 'siri_remote_play_pause_pending',
      doubleAction: [{ key_code: 'escape' }],
      settings
    }),
    createSinglePressManipulator('microphone', settings)
  ];
}

function isConfigurableButtonManipulator(manipulator) {
  return Object.values(buttonCatalog).some((button) => sameFrom(manipulator.from, button.from));
}

function createToggleManipulators(settings) {
  const button = buttonCatalog[settings.button];
  const pendingIf = {
    name: generatedVariableName,
    type: 'variable_if',
    value: 1
  };
  const pendingUnless = {
    name: generatedVariableName,
    type: 'variable_unless',
    value: 1
  };
  const clearPending = {
    set_variable: {
      name: generatedVariableName,
      value: 0
    }
  };

  const singlePressManipulator = {
    conditions: [remoteDeviceCondition, pendingUnless],
    from: button.from,
    parameters: {
      'basic.to_delayed_action_delay_milliseconds': settings.doubleClickDelayMilliseconds
    },
    to: [
      {
        set_variable: {
          name: generatedVariableName,
          value: 1
        }
      }
    ],
    to_delayed_action: {
      to_if_canceled: [clearPending],
      to_if_invoked: [clearPending, ...button.singleAction]
    },
    type: 'basic'
  };

  if (button.holdAction) {
    singlePressManipulator.parameters['basic.to_if_held_down_threshold_milliseconds'] = settings.longPressDelayMilliseconds;
    singlePressManipulator.to_if_held_down = button.holdAction;
  }

  return [
    {
      conditions: [remoteDeviceCondition, pendingIf],
      from: button.from,
      to: [
        clearPending,
        { shell_command: `/usr/bin/touch ${toggleSignalPath}` }
      ],
      type: 'basic'
    },
    singlePressManipulator
  ];
}

function getPrimaryManipulators(config) {
  const profile = config.profiles?.[0];
  const rule = profile?.complex_modifications?.rules?.[0];
  const manipulators = rule?.manipulators;
  if (!Array.isArray(manipulators)) {
    throw new Error('Karabiner 配置结构不符合预期：找不到第一个规则的 manipulators。');
  }
  return manipulators;
}

function applyTouchToggleSettings(config, rawSettings) {
  const settings = normalizeSettings(rawSettings);
  const button = buttonCatalog[settings.button];
  const manipulators = getPrimaryManipulators(config);
  const generatedManipulators = createToggleManipulators(settings);
  const baseManipulators = createBaseManipulators(settings)
    .filter((manipulator) => !isSelectedButtonManipulator(manipulator, button));
  const remainingManipulators = manipulators.filter((manipulator) => {
    if (isLegacyOrGeneratedToggleManipulator(manipulator)) {
      return false;
    }

    return !isConfigurableButtonManipulator(manipulator);
  });
  const nextConfig = structuredClone(config);

  nextConfig.profiles[0].complex_modifications.rules[0].description =
    `Siri Remote: configurable touch mouse toggle (${buttonCatalog[settings.button].label})`;
  nextConfig.profiles[0].complex_modifications.rules[0].manipulators = [
    ...generatedManipulators,
    ...baseManipulators,
    ...remainingManipulators
  ];

  return nextConfig;
}

function runSelfTest() {
  const sampleConfig = {
    profiles: [
      {
        complex_modifications: {
          rules: [
            {
              description: 'sample',
              manipulators: [
                {
                  conditions: [remoteDeviceCondition, { name: 'siri_remote_selection_pending', type: 'variable_if', value: 1 }],
                  from: { consumer_key_code: 'selection' },
                  to: [{ set_variable: { name: 'siri_remote_selection_pending', value: 0 } }, { shell_command: `/usr/bin/touch ${toggleSignalPath}` }],
                  type: 'basic'
                },
                {
                  conditions: [remoteDeviceCondition, { name: 'siri_remote_selection_pending', type: 'variable_unless', value: 1 }],
                  from: { consumer_key_code: 'selection' },
                  to: [{ set_variable: { name: 'siri_remote_selection_pending', value: 1 } }],
                  type: 'basic'
                },
                {
                  conditions: [remoteDeviceCondition],
                  from: { consumer_key_code: 'mute' },
                  to_if_alone: [{ key_code: 'delete_or_backspace' }],
                  type: 'basic'
                }
              ]
            }
          ]
        }
      }
    ]
  };

  const nextConfig = applyTouchToggleSettings(sampleConfig, {
    touchMouseToggleButton: 'mute',
    doubleClickDelayMilliseconds: 280,
    longPressDelayMilliseconds: 520
  });
  const manipulators = getPrimaryManipulators(nextConfig);

  assert.equal(manipulators.length, 10);
  assert.deepEqual(manipulators[0].from, { consumer_key_code: 'mute' });
  assert.equal(manipulators[0].to[1].shell_command, `/usr/bin/touch ${toggleSignalPath}`);
  assert.equal(manipulators[1].parameters['basic.to_delayed_action_delay_milliseconds'], 280);
  assert.equal(manipulators[1].parameters['basic.to_if_held_down_threshold_milliseconds'], 520);
  assert.deepEqual(manipulators[1].to_if_held_down, buttonCatalog.mute.holdAction);
  assert.equal(manipulators.filter((manipulator) => sameFrom(manipulator.from, buttonCatalog.mute.from)).length, 2);
  assert.equal(
    manipulators.some((manipulator) =>
      sameFrom(manipulator.from, buttonCatalog.selection.from) &&
      JSON.stringify(manipulator.to) === JSON.stringify([{ key_code: 'return_or_enter' }])
    ),
    true
  );
  assert.equal(manipulators.some((manipulator) => hasVariableCondition(manipulator, 'siri_remote_selection_pending')), false);
  assert.equal(
    manipulators.some((manipulator) =>
      sameFrom(manipulator.from, buttonCatalog.play_pause.from) &&
      (manipulator.to ?? []).some((item) => item.key_code === 'escape')
    ),
    true
  );
  assert.equal(
    manipulators.some((manipulator) =>
      sameFrom(manipulator.from, buttonCatalog.microphone.from) &&
      (manipulator.to ?? []).some((item) => item.key_code === 'escape')
    ),
    false
  );
  assert.throws(() => normalizeSettings({ touchMouseToggleButton: 'unknown' }), /未知按键/);

  console.log('[self-test] passed');
}

function main() {
  const args = new Set(process.argv.slice(2));
  if (args.has('--self-test')) {
    runSelfTest();
    return;
  }

  const settings = readJson(defaultSettingsPath);
  const config = readJson(defaultConfigPath);
  const nextConfig = applyTouchToggleSettings(config, settings);
  writeJson(defaultConfigPath, nextConfig);

  if (args.has('--install')) {
    writeJson(installedConfigPath, nextConfig);
  }

  const normalized = normalizeSettings(settings);
  console.log(`已设置：双击${buttonCatalog[normalized.button].label}开启/关闭触摸滑动`);
  console.log(`已更新：${defaultConfigPath}`);
  if (args.has('--install')) {
    console.log(`已同步：${installedConfigPath}`);
  }
}

main();
