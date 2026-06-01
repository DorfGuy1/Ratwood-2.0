import { useMemo, useState } from 'react';
import {
  Button,
  Collapsible,
  Icon,
  Input,
  NoticeBox,
  Section,
  Stack,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type OrbitTarget = {
  full_name: string;
  ref: string;
  orbiters?: number;
  job?: string;
  role?: string;
  selection_color?: string;
};

type OrbitData = {
  alive: OrbitTarget[];
  dead: OrbitTarget[];
  ghosts: OrbitTarget[];
  misc: OrbitTarget[];
  npcs: OrbitTarget[];
  orbiting_ref?: string;
};

const SECTIONS = [
  { key: 'alive', title: 'Alive', color: 'blue' },
  { key: 'dead', title: 'Dead', color: 'average' },
  { key: 'ghosts', title: 'Ghosts', color: 'label' },
  { key: 'misc', title: 'Misc', color: 'average' },
  { key: 'npcs', title: 'NPCs', color: 'average' },
] as const;

type RoleGroup = {
  label: string;
  items: OrbitTarget[];
};

function itemMatches(item: OrbitTarget, query: string) {
  if (!query) {
    return true;
  }
  const haystack = `${item.full_name} ${item.job || ''}`.toLowerCase();
  return haystack.includes(query);
}

function getRoleLabel(item: OrbitTarget) {
  return item.role || item.job || 'Unassigned';
}

function getTextColorForBackground(hex: string) {
  const sanitized = hex.replace('#', '');
  if (sanitized.length !== 6) {
    return '#f4f4f4';
  }

  const r = Number.parseInt(sanitized.slice(0, 2), 16);
  const g = Number.parseInt(sanitized.slice(2, 4), 16);
  const b = Number.parseInt(sanitized.slice(4, 6), 16);
  const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

  return luminance > 0.55 ? '#1a1a1a' : '#f4f4f4';
}

export const Orbit = (props) => {
  const { act, data } = useBackend<OrbitData>();
  const [query, setQuery] = useState('');

  const normalizedQuery = query.trim().toLowerCase();

  const sections = useMemo(() => {
    return SECTIONS.map((section) => {
      const source = (data[section.key] || []) as OrbitTarget[];
      const filtered = source.filter((item) => itemMatches(item, normalizedQuery));
      const grouped = filtered.reduce((groups, item) => {
        const label = getRoleLabel(item);
        const bucket = groups.get(label) || [];
        bucket.push(item);
        groups.set(label, bucket);
        return groups;
      }, new Map<string, OrbitTarget[]>());

      const roleGroups: RoleGroup[] = [...grouped.entries()]
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([label, items]) => ({ label, items }));

      return {
        ...section,
        items: filtered,
        roleGroups,
      };
    }).filter((section) => section.items.length > 0);
  }, [data, normalizedQuery]);

  return (
    <Window title="Orbit" width={460} height={560}>
      <Window.Content>
        <Stack fill vertical>
          <Stack.Item>
            <Section>
              <Stack align="center">
                <Stack.Item>
                  <Icon name="search" />
                </Stack.Item>
                <Stack.Item grow>
                  <Input
                    autoFocus
                    fluid
                    placeholder="Search..."
                    value={query}
                    onChange={setQuery}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button icon="sync-alt" onClick={() => act('refresh')} tooltip="Refresh" />
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          <Stack.Item grow>
            <Section fill scrollable>
              {sections.length === 0 && (
                <NoticeBox>No orbit targets match your search.</NoticeBox>
              )}

              {sections.map((section) => (
                <Collapsible key={section.key} title={`${section.title} - (${section.items.length})`}>
                  <Stack vertical>
                    {section.roleGroups.map((group) => (
                      <Stack.Item key={`${section.key}-${group.label}`}>
                        <Section
                          title={`${group.label} - (${group.items.length})`}
                        >
                          <Stack wrap>
                            {group.items.map((item) => {
                              const selected = data.orbiting_ref === item.ref;
                              const hasSelectionColor = !!item.selection_color;
                              const buttonStyle = hasSelectionColor
                                ? {
                                    backgroundColor: item.selection_color,
                                    color: getTextColorForBackground(item.selection_color as string),
                                  }
                                : undefined;
                              return (
                                <Stack.Item key={item.ref}>
                                  <Button
                                    color={hasSelectionColor ? 'transparent' : section.color}
                                    onClick={() => act('orbit', { ref: item.ref })}
                                    selected={selected}
                                    style={buttonStyle}
                                    tooltip={item.job || item.role || item.full_name}
                                    tooltipPosition="bottom-start"
                                  >
                                    <Stack>
                                      <Stack.Item>
                                        {item.full_name}
                                        {!!item.role && ` [${item.role}]`}
                                      </Stack.Item>
                                      {!!item.orbiters && (
                                        <Stack.Item>
                                          <Icon name="ghost" /> {item.orbiters}
                                        </Stack.Item>
                                      )}
                                    </Stack>
                                  </Button>
                                </Stack.Item>
                              );
                            })}
                          </Stack>
                        </Section>
                      </Stack.Item>
                    ))}
                  </Stack>
                </Collapsible>
              ))}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
