"""The adopted exploration XP curve covers every authored stage."""


def populate_planet_experience(sheet):
    columns = {cell.value: cell.column for cell in sheet[1]}
    for row in range(4, sheet.max_row + 1):
        stage = sheet.cell(row, columns['id']).value
        if stage is not None:
            sheet.cell(row, columns['planetExpRatio'],
                       0 if stage < 30 else 1.2 ** ((stage - 30) / 5))
