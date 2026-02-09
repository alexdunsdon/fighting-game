#!/usr/bin/env python3
"""
Generate PixelBrawl.rbxlx from Lua source files.
Embeds scripts into proper Roblox place XML format.
"""

import os

BASE = os.path.dirname(os.path.abspath(__file__))

# Script definitions: (file_path, script_class, script_name, service_path)
SCRIPTS = [
    {
        "file": os.path.join(BASE, "ReplicatedStorage", "FightConfig.lua"),
        "class": "ModuleScript",
        "name": "FightConfig",
        "service": "ReplicatedStorage",
    },
    {
        "file": os.path.join(BASE, "ServerScriptService", "FightServer.server.lua"),
        "class": "Script",
        "name": "FightServer",
        "service": "ServerScriptService",
    },
    {
        "file": os.path.join(BASE, "StarterPlayerScripts", "FightClient.client.lua"),
        "class": "LocalScript",
        "name": "FightClient",
        "service": "StarterPlayerScripts",  # special: child of StarterPlayer
    },
    {
        "file": os.path.join(BASE, "StarterGui", "FightHUD.client.lua"),
        "class": "LocalScript",
        "name": "FightHUD",
        "service": "StarterGui",
    },
]

# Core services in the order Roblox Studio typically lists them
SERVICES = [
    ("Workspace", "RBXF4A234D3"),
    ("Players", "RBXF4A234D4"),
    ("Lighting", "RBXF4A234D5"),
    ("ReplicatedFirst", "RBXF4A234D6"),
    ("ReplicatedStorage", "RBXF4A234D7"),
    ("ServerScriptService", "RBXF4A234D8"),
    ("ServerStorage", "RBXF4A234D9"),
    ("StarterGui", "RBXF4A234DA"),
    ("StarterPack", "RBXF4A234DB"),
    ("StarterPlayer", "RBXF4A234DC"),
    ("SoundService", "RBXF4A234DD"),
    ("Teams", "RBXF4A234DE"),
    ("Chat", "RBXF4A234DF"),
    ("LocalizationService", "RBXF4A234E0"),
    ("TestService", "RBXF4A234E1"),
]

# Sub-services that are children of other services
SUB_SERVICES = {
    "StarterPlayer": [
        ("StarterPlayerScripts", "RBXF4A234DC1"),
        ("StarterCharacterScripts", "RBXF4A234DC2"),
    ]
}

def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

def make_script_item(referent, class_name, name, source):
    """Generate an Item XML block for a script."""
    # Use CDATA to embed Lua source -- handle edge case of ]]> in source
    # by splitting CDATA sections if needed
    safe_source = source.replace("]]>", "]]]]><![CDATA[>")
    return (
        f'      <Item class="{class_name}" referent="{referent}">\n'
        f'        <Properties>\n'
        f'          <string name="Name">{name}</string>\n'
        f'          <ProtectedString name="Source"><![CDATA[{safe_source}]]></ProtectedString>\n'
        f'        </Properties>\n'
        f'      </Item>\n'
    )

def build_rbxlx():
    # Read all script sources
    script_sources = {}
    for s in SCRIPTS:
        script_sources[s["name"]] = read_file(s["file"])
        print(f"  Read {s['file']} ({len(script_sources[s['name']])} chars)")

    # Map scripts to their parent services
    # service_name -> list of script XML strings
    service_scripts = {}
    ref_counter = [100]  # mutable counter

    def next_ref():
        ref_counter[0] += 1
        return f"RBX{ref_counter[0]:08X}"

    for s in SCRIPTS:
        ref = next_ref()
        xml = make_script_item(ref, s["class"], s["name"], script_sources[s["name"]])
        svc = s["service"]
        if svc not in service_scripts:
            service_scripts[svc] = []
        service_scripts[svc].append(xml)

    # Build the full XML
    lines = []
    lines.append('<?xml version="1.0" encoding="utf-8"?>')
    lines.append('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">')
    lines.append('  <External>null</External>')
    lines.append('  <External>nil</External>')

    for svc_name, svc_ref in SERVICES:
        children_xml = ""

        # Add sub-services (e.g., StarterPlayerScripts under StarterPlayer)
        if svc_name in SUB_SERVICES:
            for sub_name, sub_ref in SUB_SERVICES[svc_name]:
                sub_scripts = "".join(service_scripts.get(sub_name, []))
                children_xml += (
                    f'    <Item class="{sub_name}" referent="{sub_ref}">\n'
                    f'      <Properties>\n'
                    f'        <string name="Name">{sub_name}</string>\n'
                    f'      </Properties>\n'
                    f'{sub_scripts}'
                    f'    </Item>\n'
                )

        # Add scripts that belong directly to this service
        children_xml += "".join(service_scripts.get(svc_name, []))

        # Build service item
        lines.append(f'  <Item class="{svc_name}" referent="{svc_ref}">')
        lines.append(f'    <Properties>')
        lines.append(f'      <string name="Name">{svc_name}</string>')
        lines.append(f'    </Properties>')
        if children_xml:
            lines.append(children_xml.rstrip("\n"))
        lines.append(f'  </Item>')

    lines.append('</roblox>')

    return "\n".join(lines) + "\n"


def main():
    print("Generating PixelBrawl.rbxlx...")
    xml = build_rbxlx()
    out_path = os.path.join(BASE, "PixelBrawl.rbxlx")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(xml)
    print(f"Written {len(xml)} bytes to {out_path}")
    print("Done!")

if __name__ == "__main__":
    main()
