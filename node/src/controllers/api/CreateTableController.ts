import {Controller} from "@tsed/di";
import {Get, Post} from "@tsed/schema";
import {BodyParams} from "@tsed/platform-params";
import {createTable, knownTables, Table, writeDB} from "zk-sql/engine/database";
import {
    pendingTablesToCreate, tableCommitments,
} from "zk-sql/engine/chainListener";
import {backOff} from "exponential-backoff";
import {commitToTable} from "zk-sql/client/client";


export type CreateTableRequest = {
    table: Table,
}


@Controller("/create")
export class CreateTableController {
    @Post()
    async updatePayload(@BodyParams() payload: CreateTableRequest): Promise<{}> {
        const commit = await commitToTable(payload.table.columns.map(c => c.name));
        await backOff(async () => {
            if (!pendingTablesToCreate.has(commit)) {
                throw Error("unknown request, commit to on-chain");
            }
        });

        createTable(payload.table);
        writeDB();
        knownTables.set(payload.table.name, payload.table.columns.map(c => c.name));
        tableCommitments.set(payload.table.name, commit);

        return {
            ok: true
        };
    }
}
