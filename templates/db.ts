// The app's browser database (IndexedDB via Dexie).
// Every read and write goes through the functions below, so moving to
// Supabase later means rewriting this file, not the components.
// Browser only: import from "use client" components or hooks.
import Dexie, { type EntityTable } from "dexie";
import { useLiveQuery } from "dexie-react-hooks";

export type Item = {
  id: string;
  title: string;
  done: boolean;
  createdAt: number;
};

const db = new Dexie("prototype-app") as Dexie & {
  items: EntityTable<Item, "id">;
};

// Schema: list the primary key, then indexed fields. Before the first deploy,
// edit this freely; once people have data, add db.version(2).stores({...}) instead.
db.version(1).stores({
  items: "id, createdAt, done",
});

export async function addItem(title: string): Promise<Item> {
  const item: Item = {
    id: crypto.randomUUID(),
    title: title.trim(),
    done: false,
    createdAt: Date.now(),
  };
  await db.items.add(item);
  return item;
}

export async function toggleItem(id: string): Promise<void> {
  const item = await db.items.get(id);
  if (item) await db.items.update(id, { done: !item.done });
}

export async function deleteItem(id: string): Promise<void> {
  await db.items.delete(id);
}

// Live list: re-renders the component whenever the table changes.
// Returns undefined while loading, so render a loading state for that.
export function useItems(): Item[] | undefined {
  return useLiveQuery(() => db.items.orderBy("createdAt").reverse().toArray());
}

// Demo helpers: every visitor to the live link starts with an empty database.
export async function loadSampleData(): Promise<void> {
  await db.items.bulkPut(
    ["Try adding your own item", "Reload: your data stays", "Tick me off"].map(
      (title, i) => ({
        id: `sample-${i}`,
        title,
        done: false,
        createdAt: Date.now() - i,
      }),
    ),
  );
}

export async function resetData(): Promise<void> {
  await db.items.clear();
}
