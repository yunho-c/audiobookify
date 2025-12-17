export interface BookData {
  id: number;
  title: string;
  author: string;
  color: string;
  textColor?: string;
  duration: number;
  rating: number;
  description: string;
}

export const BOOKS: BookData[] = [
  { id: 1, title: "THE MARTIAN", author: "Andy Weir", color: "#e74c3c", duration: 10.5, rating: 4.8, description: "Six days ago, astronaut Mark Watney became one of the first people to walk on Mars. Now, he's sure he'll be the first person to die there." },
  { id: 2, title: "DUNE", author: "Frank Herbert", color: "#d35400", duration: 21.0, rating: 4.9, description: "Set on the desert planet Arrakis, Dune is the story of the boy Paul Atreides, heir to a noble family tasked with ruling an inhospitable world where the only thing of value is the 'spice' melange." },
  { id: 3, title: "PROJECT HAIL MARY", author: "Andy Weir", color: "#f1c40f", duration: 16.2, rating: 4.9, description: "Ryland Grace is the sole survivor on a desperate, last-chance mission—and if he fails, humanity and the earth itself will perish." },
  { id: 4, title: "ATOMIC HABITS", author: "James Clear", color: "#ecf0f1", textColor: "#2c3e50", duration: 5.5, rating: 4.7, description: "No matter your goals, Atomic Habits offers a proven framework for improving--every day." },
  { id: 5, title: "STEVE JOBS", author: "Walter Isaacson", color: "#ffffff", textColor: "#000000", duration: 25.0, rating: 4.6, description: "Based on more than forty interviews with Jobs conducted over two years." },
  { id: 6, title: "DARK MATTER", author: "Blake Crouch", color: "#2c3e50", duration: 9.0, rating: 4.5, description: "Are you happy in your life? Those are the last words Jason Dessen hears before the masked abductor knocks him unconscious." },
  { id: 7, title: "1984", author: "George Orwell", color: "#8e44ad", duration: 11.0, rating: 4.6, description: "Among the seminal texts of the 20th century, Nineteen Eighty-Four is a rare work that grows more haunting as its futuristic purgatory becomes more real." },
  { id: 8, title: "SAPIENS", author: "Yuval Noah Harari", color: "#27ae60", duration: 15.0, rating: 4.7, description: "From a renowned historian comes a groundbreaking narrative of humanity's creation and evolution." },
];
