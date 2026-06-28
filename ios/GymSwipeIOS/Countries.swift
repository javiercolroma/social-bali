import Foundation

struct Country {
    let name: String
    let flag: String
    let cities: [String]
}

let countries: [Country] = [
    Country(name: "España", flag: "🇪🇸", cities: ["Madrid", "Barcelona", "Valencia", "Sevilla", "Bilbao", "Málaga", "Zaragoza", "Murcia", "Palma", "Las Palmas", "Granada", "Alicante", "Vigo", "Valladolid", "Córdoba", "Gijón", "San Sebastián", "Pamplona", "Santander", "Otra"]),
    Country(name: "México", flag: "🇲🇽", cities: ["Ciudad de México", "Guadalajara", "Monterrey", "Puebla", "Tijuana", "León", "Querétaro", "Mérida", "Cancún", "Otra"]),
    Country(name: "Argentina", flag: "🇦🇷", cities: ["Buenos Aires", "Córdoba", "Rosario", "Mendoza", "La Plata", "Mar del Plata", "Salta", "Otra"]),
    Country(name: "Colombia", flag: "🇨🇴", cities: ["Bogotá", "Medellín", "Cali", "Barranquilla", "Cartagena", "Bucaramanga", "Otra"]),
    Country(name: "Chile", flag: "🇨🇱", cities: ["Santiago", "Valparaíso", "Concepción", "Viña del Mar", "Antofagasta", "Otra"]),
    Country(name: "Perú", flag: "🇵🇪", cities: ["Lima", "Arequipa", "Trujillo", "Cusco", "Piura", "Otra"]),
    Country(name: "Estados Unidos", flag: "🇺🇸", cities: ["Nueva York", "Los Ángeles", "Miami", "Chicago", "Houston", "San Francisco", "Otra"]),
    Country(name: "Reino Unido", flag: "🇬🇧", cities: ["Londres", "Manchester", "Birmingham", "Liverpool", "Edimburgo", "Otra"]),
    Country(name: "Francia", flag: "🇫🇷", cities: ["París", "Lyon", "Marsella", "Toulouse", "Niza", "Otra"]),
    Country(name: "Alemania", flag: "🇩🇪", cities: ["Berlín", "Múnich", "Hamburgo", "Colonia", "Fráncfort", "Otra"]),
    Country(name: "Italia", flag: "🇮🇹", cities: ["Roma", "Milán", "Nápoles", "Turín", "Florencia", "Otra"]),
    Country(name: "Portugal", flag: "🇵🇹", cities: ["Lisboa", "Oporto", "Braga", "Coímbra", "Faro", "Otra"]),
]

func countryFlag(_ name: String) -> String {
    countries.first { $0.name == name }?.flag ?? "🌍"
}

func cities(for country: String) -> [String] {
    countries.first { $0.name == country }?.cities ?? ["Otra"]
}
