.pragma library

// Emoji searched by the launcher after ":". Each entry is the character and
// its Spanish and English keywords.
const list = [
    ["😀", "sonrisa feliz grin smile happy"], ["😂", "risa lagrimas joy laugh"], ["🤣", "carcajada rofl laugh"],
    ["😊", "sonrojo feliz blush smile"], ["😍", "enamorado corazones love heart eyes"], ["😘", "beso kiss"],
    ["😉", "guiño wink"], ["😎", "gafas guay cool sunglasses"], ["🤔", "pensando thinking"],
    ["😐", "neutral serio"], ["🙄", "ojos rodar eyeroll"], ["😴", "dormir sueño sleep"],
    ["😅", "sudor nervios sweat smile"], ["😭", "llorar llanto cry sob"], ["😢", "triste lagrima sad cry"],
    ["😡", "enfadado rabia angry"], ["😱", "miedo grito scream fear"], ["🥳", "fiesta celebrar party"],
    ["🤯", "explota mente mind blown"], ["😬", "mueca grimace"], ["🤗", "abrazo hug"],
    ["🙃", "al reves upside down"], ["😇", "angel inocente halo"], ["🥺", "suplicar pleading"],
    ["🤡", "payaso clown"], ["💀", "calavera muerto skull dead"], ["👻", "fantasma ghost"],
    ["🤖", "robot bot"], ["💩", "caca poop"], ["👍", "bien ok pulgar arriba thumbs up like"],
    ["👎", "mal pulgar abajo thumbs down dislike"], ["👏", "aplausos clap"], ["🙌", "celebrar manos arriba raise hands"],
    ["🙏", "gracias por favor rezar pray thanks"], ["👋", "hola adios saludo wave hello"], ["🤝", "acuerdo trato handshake"],
    ["💪", "fuerza musculo strong"], ["✌️", "paz victoria peace"], ["🤞", "suerte dedos cruzados luck"],
    ["👌", "perfecto ok"], ["👀", "ojos mirar eyes look"], ["🧠", "cerebro brain"],
    ["❤️", "corazon rojo amor heart love red"], ["🧡", "corazon naranja orange heart"], ["💛", "corazon amarillo yellow heart"],
    ["💚", "corazon verde green heart"], ["💙", "corazon azul blue heart"], ["💜", "corazon morado purple heart"],
    ["🖤", "corazon negro black heart"], ["💔", "corazon roto broken heart"], ["✨", "brillos chispas sparkles"],
    ["🔥", "fuego fire hot"], ["⭐", "estrella star"], ["🌟", "estrella brillante glowing star"],
    ["⚡", "rayo electricidad lightning zap"], ["💯", "cien hundred"], ["✅", "hecho check ok done"],
    ["❌", "error cruz no cross"], ["⚠️", "aviso advertencia warning"], ["❓", "pregunta question"],
    ["❗", "exclamacion exclamation"], ["🎉", "fiesta confeti tada party"], ["🎁", "regalo gift"],
    ["🎂", "tarta cumpleaños cake birthday"], ["🎵", "musica nota music"], ["🎮", "videojuego mando game"],
    ["💻", "portatil ordenador laptop computer"], ["🖥️", "monitor escritorio desktop"], ["⌨️", "teclado keyboard"],
    ["📱", "movil telefono phone"], ["📷", "camara foto camera"], ["💡", "idea bombilla bulb"],
    ["🔒", "candado cerrado lock"], ["🔑", "llave key"], ["🔧", "llave inglesa herramienta wrench"],
    ["⚙️", "engranaje ajustes gear settings"], ["🐛", "bicho bug"], ["🚀", "cohete lanzar rocket launch"],
    ["📦", "paquete caja package box"], ["📁", "carpeta folder"], ["📝", "nota escribir memo note"],
    ["📅", "calendario fecha calendar"], ["⏰", "alarma reloj alarm clock"], ["⏳", "espera reloj arena hourglass"],
    ["📌", "chincheta pin"], ["🔗", "enlace link"], ["📧", "correo email mail"],
    ["💬", "mensaje chat bocadillo speech"], ["🔔", "campana notificacion bell"], ["🔍", "buscar lupa search"],
    ["💰", "dinero money bag"], ["💸", "gastar dinero money wings"], ["📈", "subida grafico chart up"],
    ["📉", "bajada grafico chart down"], ["🏠", "casa hogar home house"], ["🌍", "mundo tierra world earth globe"],
    ["☀️", "sol sun"], ["🌙", "luna noche moon"], ["☁️", "nube cloud"],
    ["🌧️", "lluvia rain"], ["❄️", "nieve frio snow cold"], ["🌈", "arcoiris rainbow"],
    ["🌸", "flor cerezo flower blossom"], ["🌱", "planta brote seedling"], ["🍀", "trebol suerte clover"],
    ["🐶", "perro dog"], ["🐱", "gato cat"], ["🦊", "zorro fox"],
    ["🐼", "panda"], ["🐧", "pinguino penguin linux"], ["🦄", "unicornio unicorn"],
    ["🍕", "pizza"], ["🍔", "hamburguesa burger"], ["🍟", "patatas fries"],
    ["🍺", "cerveza beer"], ["🍷", "vino wine"], ["☕", "cafe coffee"],
    ["🍎", "manzana apple"], ["🍌", "platano banana"], ["🍫", "chocolate"],
    ["⚽", "futbol balon soccer football"], ["🏆", "trofeo ganar trophy"], ["🥇", "medalla oro primero gold medal"],
    ["🚗", "coche car"], ["✈️", "avion plane"], ["🎯", "diana objetivo target"],
    ["👉", "derecha señalar point right"], ["👈", "izquierda señalar point left"], ["👆", "arriba señalar point up"],
    ["👇", "abajo señalar point down"], ["➡️", "flecha derecha arrow right"], ["⬅️", "flecha izquierda arrow left"],
    ["🙈", "mono no ver see no evil monkey"], ["🤷", "no se encogerse shrug"], ["🤦", "facepalm"]
];

// Entries whose keywords contain every word of the query.
function search(query) {
    const words = query.toLocaleLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").split(/\s+/).filter(word => word);
    return list.filter(([, keywords]) => words.every(word => keywords.normalize("NFD").replace(/[̀-ͯ]/g, "").includes(word)));
}
