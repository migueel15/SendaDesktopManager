package wallpaper

type Backend interface {
	Set(wallpaper Wallpaper, options SetOptions) error
}

type Service struct {
	backend Backend
}

func NewService(backend Backend) *Service {
	return &Service{
		backend: backend,
	}
}

func (s *Service) Set(w Wallpaper, options SetOptions) {
	s.backend.Set(w, options)
}
