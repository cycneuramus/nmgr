from typing import Callable, Dict, Generic, Type, TypeVar

T = TypeVar("T")
SubclassType = Type[T]
RegistryDecorator = Callable[[SubclassType], SubclassType]


class RegistryMixin(Generic[T]):
    """Generic registry mixin with per-subclass registries"""

    def __init_subclass__(cls) -> None:
        cls._registry: Dict[str, SubclassType] = {}

    @classmethod
    def register(cls, key: str) -> RegistryDecorator:
        """Decorator for registering subclasses"""

        def decorator(subclass: SubclassType) -> SubclassType:
            if key in cls._registry:
                raise ValueError(f"{key} is already registered to {cls._registry[key]}")
            cls._registry[key] = subclass
            return subclass

        return decorator

    @classmethod
    def get_subclass(cls, key: str) -> SubclassType:
        """Retrieve registered subclass by key"""

        try:
            return cls._registry[key]
        except KeyError:
            raise ValueError(f"No class registered for key: {key}")

    @classmethod
    def get_registry_keys(cls) -> list[str]:
        """Get list of registry keys"""

        return list(cls._registry.keys())
