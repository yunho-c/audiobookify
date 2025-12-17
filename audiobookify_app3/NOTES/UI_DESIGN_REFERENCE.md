import React, { useState, useEffect, useRef } from 'react';
import { 
  Play, Pause, SkipForward, SkipBack, Home, Library, Search, 
  User, Clock, Moon, List, Heart, Share2, MoreHorizontal, 
  ChevronDown, Bookmark, Headphones, X, Volume2
} from 'lucide-react';

// --- Mock Data ---

const BOOKS = [
  {
    id: 1,
    title: "The Silent Stars",
    author: "Elena Fisher",
    cover: "https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=600&auto=format&fit=crop",
    progress: 45,
    duration: "12h 30m",
    timeLeft: "6h 15m",
    color: "from-blue-900 to-slate-900",
    description: "A journey through the cosmos seeking silence in a noisy universe."
  },
  {
    id: 2,
    title: "Echoes of Old",
    author: "Marcus Thorne",
    cover: "https://images.unsplash.com/photo-1461360370896-922624d12aa1?q=80&w=600&auto=format&fit=crop",
    progress: 12,
    duration: "8h 45m",
    timeLeft: "7h 30m",
    color: "from-amber-900 to-stone-900",
    description: "History refuses to stay buried in this gripping mystery."
  },
  {
    id: 3,
    title: "Neon Dreams",
    author: "Sarah J. Watts",
    cover: "https://images.unsplash.com/photo-1555680202-c86f0e12f086?q=80&w=600&auto=format&fit=crop",
    progress: 0,
    duration: "10h 15m",
    timeLeft: "10h 15m",
    color: "from-purple-900 to-indigo-900",
    description: "Cyberpunk noir thriller set in the year 2089."
  },
  {
    id: 4,
    title: "Mountain Path",
    author: "David Chen",
    cover: "https://images.unsplash.com/photo-1519681393784-d120267933ba?q=80&w=600&auto=format&fit=crop",
    progress: 88,
    duration: "6h 20m",
    timeLeft: "45m",
    color: "from-emerald-900 to-teal-900",
    description: "Finding peace one step at a time in the Himalayas."
  },
  {
    id: 5,
    title: "Abstract Minds",
    author: "Dr. Emily Ray",
    cover: "https://images.unsplash.com/photo-1541963463532-d68292c34b19?q=80&w=600&auto=format&fit=crop",
    progress: 0,
    duration: "14h 00m",
    timeLeft: "14h 00m",
    color: "from-pink-900 to-rose-900",
    description: "Understanding the psychology of creativity."
  }
];

// --- Components ---

const ProgressBar = ({ progress, className = "" }) => (
  <div className={`h-1.5 w-full bg-white/10 rounded-full overflow-hidden ${className}`}>
    <div 
      className="h-full bg-white rounded-full transition-all duration-300 ease-out" 
      style={{ width: `${progress}%` }}
    />
  </div>
);

const IconButton = ({ icon: Icon, onClick, className = "", size = 24 }) => (
  <button 
    onClick={(e) => {
      e.stopPropagation();
      onClick && onClick();
    }}
    className={`p-2 rounded-full hover:bg-white/10 active:scale-95 transition-all ${className}`}
  >
    <Icon size={size} />
  </button>
);

const BookCard = ({ book, onClick, compact = false }) => (
  <div 
    onClick={() => onClick(book)}
    className={`group relative flex-shrink-0 cursor-pointer transition-all duration-300 ${compact ? 'w-32 mr-4' : 'w-40 mr-6'}`}
  >
    <div className={`relative aspect-[2/3] rounded-xl overflow-hidden shadow-lg mb-3 ${compact ? 'shadow-md' : 'shadow-xl'}`}>
      <img 
        src={book.cover} 
        alt={book.title}
        className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110"
      />
      {book.progress > 0 && book.progress < 100 && (
        <div className="absolute bottom-0 left-0 right-0 h-1 bg-black/50">
          <div 
            className="h-full bg-orange-500" 
            style={{ width: `${book.progress}%` }}
          />
        </div>
      )}
      <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors" />
    </div>
    <h3 className="text-white font-medium truncate text-sm leading-tight mb-1">{book.title}</h3>
    <p className="text-white/60 text-xs truncate">{book.author}</p>
  </div>
);

const SectionHeader = ({ title, action = "See All" }) => (
  <div className="flex justify-between items-end mb-4 px-6">
    <h2 className="text-xl font-bold text-white">{title}</h2>
    <button className="text-orange-400 text-xs font-semibold hover:text-orange-300 transition-colors">
      {action}
    </button>
  </div>
);

// --- Views ---

const HomeView = ({ onPlayBook }) => {
  const currentHour = new Date().getHours();
  const greeting = currentHour < 12 ? "Good Morning" : currentHour < 18 ? "Good Afternoon" : "Good Evening";

  return (
    <div className="pb-32 pt-14 animate-fade-in">
      {/* Header */}
      <div className="px-6 mb-8 flex justify-between items-center">
        <div>
          <p className="text-white/60 text-sm mb-1 uppercase tracking-wider font-medium">{greeting}</p>
          <h1 className="text-3xl font-bold text-white">Ready to listen?</h1>
        </div>
        <div className="w-10 h-10 rounded-full bg-gradient-to-br from-orange-400 to-pink-500 flex items-center justify-center shadow-lg cursor-pointer hover:scale-105 transition-transform">
          <User className="text-white" size={20} />
        </div>
      </div>

      {/* Continue Listening Hero */}
      <div className="px-6 mb-10">
        <div 
          onClick={() => onPlayBook(BOOKS[0])}
          className="relative w-full aspect-[2/1] rounded-2xl overflow-hidden bg-gradient-to-r from-slate-800 to-slate-900 shadow-2xl cursor-pointer group"
        >
          {/* Background blurred image */}
          <div 
            className="absolute inset-0 opacity-40 mix-blend-overlay transition-transform duration-700 group-hover:scale-105"
            style={{ backgroundImage: `url(${BOOKS[0].cover})`, backgroundSize: 'cover', backgroundPosition: 'center' }}
          />
          
          <div className="absolute inset-0 p-5 flex flex-col justify-between z-10 bg-gradient-to-t from-black/80 via-transparent to-transparent">
            <div className="flex justify-between items-start">
              <span className="bg-white/20 backdrop-blur-md px-2 py-1 rounded text-[10px] font-bold tracking-wide text-white">
                CONTINUE LISTENING
              </span>
              <div className="w-8 h-8 rounded-full bg-white flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
                <Play size={14} className="text-slate-900 fill-slate-900 ml-0.5" />
              </div>
            </div>
            
            <div className="flex items-end gap-4">
              <img src={BOOKS[0].cover} alt="Cover" className="w-16 h-24 rounded shadow-lg object-cover" />
              <div className="flex-1 min-w-0 pb-1">
                <h3 className="text-xl font-bold text-white truncate mb-1">{BOOKS[0].title}</h3>
                <p className="text-white/70 text-sm truncate mb-3">{BOOKS[0].author}</p>
                <div className="flex items-center gap-3 text-xs text-white/50 mb-2">
                  <span>{BOOKS[0].timeLeft} left</span>
                  <span className="bg-white/20 h-3 w-[1px]"></span>
                  <span>{BOOKS[0].progress}% complete</span>
                </div>
                <ProgressBar progress={BOOKS[0].progress} />
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Recommended */}
      <div className="mb-10">
        <SectionHeader title="Recommended For You" />
        <div className="flex overflow-x-auto px-6 pb-6 pt-2 scrollbar-hide snap-x">
          {BOOKS.slice(1).map(book => (
            <BookCard key={book.id} book={book} onClick={onPlayBook} />
          ))}
        </div>
      </div>

      {/* New Releases */}
      <div className="mb-8">
        <SectionHeader title="Fresh Arrivals" />
        <div className="flex overflow-x-auto px-6 pb-6 pt-2 scrollbar-hide snap-x">
          {[...BOOKS].reverse().map(book => (
            <BookCard key={`new-${book.id}`} book={book} onClick={onPlayBook} compact />
          ))}
        </div>
      </div>
    </div>
  );
};

const LibraryView = ({ onPlayBook }) => (
  <div className="pt-14 pb-32 px-6 h-full flex flex-col animate-fade-in">
    <h1 className="text-3xl font-bold text-white mb-6">Your Library</h1>
    
    <div className="flex gap-4 mb-6 overflow-x-auto pb-2 scrollbar-hide">
      {['All', 'Downloaded', 'Finished', 'Authors'].map((filter, idx) => (
        <button 
          key={filter}
          className={`px-5 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-colors ${
            idx === 0 
            ? 'bg-white text-black shadow-lg' 
            : 'bg-white/5 text-white/70 hover:bg-white/10'
          }`}
        >
          {filter}
        </button>
      ))}
    </div>

    <div className="grid grid-cols-2 gap-x-4 gap-y-8 overflow-y-auto pb-20">
      {BOOKS.map(book => (
        <div key={book.id} onClick={() => onPlayBook(book)} className="cursor-pointer group">
          <div className="aspect-[2/3] rounded-xl overflow-hidden mb-3 relative shadow-lg">
            <img 
              src={book.cover} 
              alt={book.title} 
              className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110"
            />
             {book.progress > 0 && (
              <div className="absolute top-2 right-2 bg-black/60 backdrop-blur-md px-2 py-1 rounded text-[10px] font-bold text-white">
                {book.progress}%
              </div>
            )}
          </div>
          <h3 className="text-white font-medium text-sm truncate">{book.title}</h3>
          <p className="text-white/50 text-xs truncate">{book.author}</p>
        </div>
      ))}
    </div>
  </div>
);

const FullPlayer = ({ book, isPlaying, togglePlay, onClose, show }) => {
  const [showChapters, setShowChapters] = useState(false);
  const [sliderVal, setSliderVal] = useState(book?.progress || 0);

  // Close player when swiping down (mock interaction)
  // In a real app, we'd use a gesture library
  
  if (!book) return null;

  return (
    <div 
      className={`fixed inset-0 z-50 flex flex-col bg-slate-900 transition-all duration-500 ease-[cubic-bezier(0.32,0.72,0,1)] ${
        show ? 'translate-y-0 opacity-100' : 'translate-y-full opacity-0 pointer-events-none'
      }`}
    >
      {/* Ambient Background */}
      <div 
        className="absolute inset-0 opacity-30 pointer-events-none transition-colors duration-1000"
        style={{ 
          background: `linear-gradient(to bottom, transparent, black), url(${book.cover})`,
          backgroundSize: 'cover',
          filter: 'blur(60px) saturate(200%)'
        }}
      />
      <div className={`absolute inset-0 bg-gradient-to-b ${book.color} to-black opacity-80`} />

      {/* Header */}
      <div className="relative z-10 flex justify-between items-center p-6 pt-12">
        <IconButton icon={ChevronDown} onClick={onClose} />
        <span className="text-xs font-bold tracking-widest text-white/50 uppercase">Now Playing</span>
        <IconButton icon={MoreHorizontal} />
      </div>

      {/* Main Content */}
      <div className="relative z-10 flex-1 flex flex-col px-8 overflow-y-auto no-scrollbar">
        
        {/* Album Art */}
        <div className="flex-1 flex items-center justify-center py-4 min-h-[300px]">
          <div className="relative w-full max-w-xs aspect-square rounded-2xl shadow-2xl overflow-hidden ring-1 ring-white/10">
            <img 
              src={book.cover} 
              alt={book.title} 
              className="w-full h-full object-cover"
            />
          </div>
        </div>

        {/* Info & Controls */}
        <div className="pb-12">
          <div className="flex justify-between items-start mb-8">
            <div>
              <h2 className="text-2xl font-bold text-white mb-1 line-clamp-2 leading-tight">{book.title}</h2>
              <p className="text-lg text-white/60">{book.author}</p>
            </div>
            <IconButton icon={Heart} className="text-white/40 hover:text-red-500" />
          </div>

          {/* Scrubber */}
          <div className="mb-8 group">
            <div className="relative h-2 bg-white/10 rounded-full cursor-pointer group-hover:h-3 transition-all duration-300">
               <div 
                className="absolute top-0 left-0 h-full bg-white rounded-full flex items-center justify-end"
                style={{ width: `${sliderVal}%` }}
              >
                <div className="w-4 h-4 bg-white rounded-full shadow-lg scale-0 group-hover:scale-100 transition-transform translate-x-1/2" />
              </div>
            </div>
            <div className="flex justify-between mt-2 text-xs font-medium text-white/40 font-mono">
              <span>12:45</span>
              <span>-5:23</span>
            </div>
          </div>

          {/* Main Controls */}
          <div className="flex justify-between items-center mb-10">
            <IconButton icon={SkipBack} size={28} className="text-white/70" />
            <button className="w-12 h-12 flex items-center justify-center rounded-full text-white hover:bg-white/10 font-bold text-sm">
              15s
            </button>
            <button 
              onClick={togglePlay}
              className="w-20 h-20 bg-white rounded-full flex items-center justify-center shadow-xl hover:scale-105 active:scale-95 transition-all text-slate-900"
            >
              {isPlaying ? <Pause size={32} fill="currentColor" /> : <Play size={32} fill="currentColor" className="ml-1"/>}
            </button>
            <button className="w-12 h-12 flex items-center justify-center rounded-full text-white hover:bg-white/10 font-bold text-sm">
              30s
            </button>
            <IconButton icon={SkipForward} size={28} className="text-white/70" />
          </div>

          {/* Bottom Actions */}
          <div className="flex justify-between px-4">
            <div className="flex flex-col items-center gap-1 text-white/50 hover:text-white cursor-pointer transition-colors">
              <Clock size={20} />
              <span className="text-[10px] font-medium">Speed 1.0x</span>
            </div>
            <div className="flex flex-col items-center gap-1 text-white/50 hover:text-white cursor-pointer transition-colors">
              <Moon size={20} />
              <span className="text-[10px] font-medium">Sleep</span>
            </div>
            <div className="flex flex-col items-center gap-1 text-white/50 hover:text-white cursor-pointer transition-colors">
              <List size={20} />
              <span className="text-[10px] font-medium">Chapters</span>
            </div>
            <div className="flex flex-col items-center gap-1 text-white/50 hover:text-white cursor-pointer transition-colors">
              <Share2 size={20} />
              <span className="text-[10px] font-medium">Share</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const MiniPlayer = ({ book, isPlaying, togglePlay, onExpand }) => {
  if (!book) return null;

  return (
    <div 
      className="fixed bottom-20 left-4 right-4 h-16 bg-slate-800/90 backdrop-blur-xl rounded-xl shadow-2xl flex items-center pr-4 pl-2 gap-3 z-40 border border-white/5 cursor-pointer animate-slide-up"
      onClick={onExpand}
    >
      <img src={book.cover} alt="Cover" className="w-12 h-12 rounded-lg object-cover shadow-sm" />
      <div className="flex-1 min-w-0 flex flex-col justify-center">
        <h4 className="text-white font-semibold text-sm truncate leading-tight">{book.title}</h4>
        <p className="text-white/50 text-xs truncate leading-tight">{book.author}</p>
      </div>
      <div className="flex items-center gap-1">
        <IconButton icon={Volume2} size={18} className="text-white/50" />
        <button 
          onClick={(e) => { e.stopPropagation(); togglePlay(); }}
          className="w-10 h-10 rounded-full bg-white flex items-center justify-center shadow hover:scale-105 active:scale-95 transition-all ml-1"
        >
          {isPlaying ? 
            <Pause size={18} className="text-slate-900 fill-slate-900" /> : 
            <Play size={18} className="text-slate-900 fill-slate-900 ml-0.5" />
          }
        </button>
      </div>
      
      {/* Progress Line */}
      <div className="absolute bottom-0 left-2 right-2 h-[2px] bg-white/10 overflow-hidden rounded-full">
        <div className="h-full bg-orange-500 w-[45%]" />
      </div>
    </div>
  );
};

const NavBar = ({ activeTab, setActiveTab }) => {
  const tabs = [
    { id: 'home', icon: Home, label: 'Home' },
    { id: 'search', icon: Search, label: 'Search' },
    { id: 'library', icon: Library, label: 'Library' },
  ];

  return (
    <div className="fixed bottom-0 left-0 right-0 h-20 bg-gradient-to-t from-black to-slate-900/95 backdrop-blur-lg flex justify-around items-start pt-4 z-40 pb-safe">
      {tabs.map(tab => {
        const isActive = activeTab === tab.id;
        const Icon = tab.icon;
        return (
          <button 
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className="flex flex-col items-center w-16 group"
          >
            <div className={`relative mb-1 transition-all duration-300 ${isActive ? '-translate-y-1' : ''}`}>
              <Icon 
                size={24} 
                className={`transition-colors duration-300 ${isActive ? 'text-white' : 'text-white/40 group-hover:text-white/70'}`} 
                strokeWidth={isActive ? 2.5 : 2}
              />
              {isActive && (
                <div className="absolute -bottom-2 left-1/2 -translate-x-1/2 w-1 h-1 bg-orange-500 rounded-full shadow-[0_0_8px_rgba(249,115,22,0.8)]" />
              )}
            </div>
            <span className={`text-[10px] font-medium transition-colors ${isActive ? 'text-white' : 'text-white/40'}`}>
              {tab.label}
            </span>
          </button>
        );
      })}
    </div>
  );
};

// --- Main App Component ---

export default function AudiobookApp() {
  const [activeTab, setActiveTab] = useState('home');
  const [activeBook, setActiveBook] = useState(BOOKS[0]);
  const [isPlaying, setIsPlaying] = useState(false);
  const [showFullPlayer, setShowFullPlayer] = useState(false);

  const handlePlayBook = (book) => {
    if (activeBook?.id === book.id) {
      setShowFullPlayer(true);
    } else {
      setActiveBook(book);
      setIsPlaying(true);
      setShowFullPlayer(true);
    }
  };

  const togglePlay = () => setIsPlaying(!isPlaying);

  return (
    <div className="relative w-full h-screen bg-black text-white overflow-hidden font-sans selection:bg-orange-500/30">
      
      {/* Content Area */}
      <div className="h-full overflow-y-auto no-scrollbar scroll-smooth">
        {activeTab === 'home' && <HomeView onPlayBook={handlePlayBook} />}
        {activeTab === 'library' && <LibraryView onPlayBook={handlePlayBook} />}
        {activeTab === 'search' && (
          <div className="pt-20 px-6 text-center text-white/40 flex flex-col items-center justify-center h-full pb-32">
            <div className="w-16 h-16 bg-white/5 rounded-full flex items-center justify-center mb-4">
              <Search size={32} />
            </div>
            <p>Search functionality coming soon</p>
          </div>
        )}
      </div>

      {/* Navigation & Player Overlays */}
      <div className="z-40">
        {!showFullPlayer && activeBook && (
          <MiniPlayer 
            book={activeBook} 
            isPlaying={isPlaying} 
            togglePlay={togglePlay}
            onExpand={() => setShowFullPlayer(true)}
          />
        )}
        
        <NavBar activeTab={activeTab} setActiveTab={setActiveTab} />
      </div>

      {/* Full Screen Player */}
      <FullPlayer 
        book={activeBook} 
        isPlaying={isPlaying} 
        togglePlay={togglePlay} 
        show={showFullPlayer}
        onClose={() => setShowFullPlayer(false)}
      />

      <style jsx global>{`
        .no-scrollbar::-webkit-scrollbar {
          display: none;
        }
        .no-scrollbar {
          -ms-overflow-style: none;
          scrollbar-width: none;
        }
        .pb-safe {
          padding-bottom: env(safe-area-inset-bottom);
        }
        @keyframes fade-in {
          from { opacity: 0; transform: translateY(10px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .animate-fade-in {
          animation: fade-in 0.4s ease-out forwards;
        }
        @keyframes slide-up {
          from { transform: translateY(100%); opacity: 0; }
          to { transform: translateY(0); opacity: 1; }
        }
        .animate-slide-up {
          animation: slide-up 0.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
        }
      `}</style>
    </div>
  );
}