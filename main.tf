########################################### OJO ##############################################
# AWS NAT Gateway no está incluído en el Free Tier. Levántalo bajo tu propia responsabilidad #
##############################################################################################


# Declaramos las variables

variable "region" {
  description = "Región donde ubicaremos la infraerstructura."
  type        = string
  default     = "eu-west-1"
}

variable "instance_type" {
  description = "Tipo de instancia EC2 con la que vamos a trabajar."
  type    = string
  default = "t2.micro"
}

variable "ami" {
  description = "Ami para las instancias de EC2"
  type        = string
  default     = "ami-0701e7be9b2a77600"
}

variable "zona_publica" {                                          # Por el momento solo necesitamos una zona pública, si después se necesitan más tendremos que cambiar a otro tipo de estructura.
  description = "Zona de la región que utilizaremos como pública." # Debo evaluar si la zona publica se almacenará en una variable a parte o bien se indicará que es pública mediante atributo
  type        = string                                             # en una posible estructura de tipo map.
  default     = "eu-west-1a"                                       #
}                                                                  #

variable "zona_privada_a" {                                         # Estas redes privadas son claramente iterables en la lógica que las usa, por lo que se almacenarán en otro tipo de estructura
  description = "Zona de la región a que utilizaremos como privada."# en el futuro. Seguramente un objeto tipo map que nos permita asociar cada nombre de red con su direccionamiento y/o propiedades.
  type        = string                                              #
  default     = "eu-west-1a"                                        #
}                                                                   #
                                                                    #
variable "zona_privada_b" {                                         #
  description = "Zona de la región b que utilizaremos como privada."#
  type        = string                                              #
  default     = "eu-west-1b"                                        #
}                                                                   #
                                                                    #
variable "zona_privada_c" {                                         #
  description = "Zona de la región c que utilizaremos como privada."#
  type        = string                                              #
  default     = "eu-west-1c"                                        #
}                                                                   #
# En el futuro se declararán como variables de tipo map los servicios personalizados a permitir en la ACL y los Security Groups, así como el origen y la acción a realizar.
# También se construirán objetos que describirán las redes y sus atributos, siendo la red del VPC la clave principal y las subredes claves de segundo nivel.
####################################

# Configuramos el provider

provider "aws" {
  version = "~> 2.0"
  region = var.region
}
####################################

# Creamos el VPC con la red principal
resource "aws_vpc" "my_first_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "firstVPC"
  }
}
####################################

# Creamos la Internet Gateway

resource "aws_internet_gateway" "my_first_vpc_gateway" {
  vpc_id = aws_vpc.my_first_vpc.id

  tags = {
    Name = "Internet Gateway of VPC ${aws_vpc.my_first_vpc.tags.Name}"
  }
}
####################################

# Creamos la subredes del VPC, una por cada zona de disponibilidad más la pública
# La declaración de las redes también puede hacerse de forma iterativa desde una estructura de tipo map, la clave indicará el nombre y los atributos indicarán el bloque CIDR y la zona de disponibilidad.
# Por el momento no se plantea un desarrollo multi VPC 

resource "aws_subnet" "my_first_vpc_net" {
  vpc_id     = aws_vpc.my_first_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = var.zona_privada_a

  tags = {
    Name = "Private Net ${var.zona_privada_a}"
  }
}

resource "aws_subnet" "my_second_vpc_net" {
  vpc_id     = aws_vpc.my_first_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = var.zona_privada_b

  tags = {
    Name = "Private Net ${var.zona_privada_b}"
  }
}

resource "aws_subnet" "my_third_vpc_net" {
  vpc_id     = aws_vpc.my_first_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = var.zona_privada_c

  tags = {
    Name = "Private Net ${var.zona_privada_c}"
  }
}

resource "aws_subnet" "my_vpc_public_net" {
  vpc_id     = aws_vpc.my_first_vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = var.zona_publica
  map_public_ip_on_launch = true

  tags = {
    Name = "Public zone of ${aws_vpc.my_first_vpc.tags.Name}, located in zone ${var.zona_publica}"
  }
}
####################################

# Creamos las ACL. Actua a nivel de seguridad de firewall.
# OJO, que las ACL son stateless, así que hay que abrir los puertos no privilegiados o se pierde la comunicación. 
# Este comportamiento puede suponer una complejidad bastante alta, hay que evaluar el uso de ACLS o solo security groups.
# Los servicios personalizados que permitimos, como SSH o Web, son claramente iterables por una estructura correcta. Se añadirá en el futuro.
# Los subnet's ids y sus dependendcias también pueden ser establecidas de forma iterativa. No es necesario indicar las dependencias puesto que al ser referencias, terraform lo trata y resuelve de forma interna.

resource "aws_network_acl" "allow_web_and_ssh" {
  vpc_id = aws_vpc.my_first_vpc.id
  subnet_ids = [aws_subnet.my_vpc_public_net.id, aws_subnet.my_first_vpc_net.id, aws_subnet.my_second_vpc_net.id, aws_subnet.my_third_vpc_net.id]
  depends_on = [aws_subnet.my_vpc_public_net, aws_subnet.my_first_vpc_net, aws_subnet.my_second_vpc_net, aws_subnet.my_third_vpc_net]

  ingress {
    action = "allow"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_block  = "0.0.0.0/0"
    rule_no     = 70
  }

  ingress {
    action = "allow"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_block  = "0.0.0.0/0"
    rule_no     = 80
  }

  ingress {
    action = "allow"
    from_port   = 0
    to_port     = 0
    protocol    = "icmp"
    icmp_type   = "-1"
    icmp_code   = "-1"
    cidr_block  = "0.0.0.0/0"
    rule_no     = 97
  }

  ingress {
    action = "allow"
    from_port   = 1024
    to_port     = 65535
    protocol    = "udp"
    cidr_block  = "0.0.0.0/0"
    rule_no     = 98
  }

  ingress {
    action = "allow"
    from_port   = 1024
    to_port     = 65535
    protocol    = "tcp"
    cidr_block  = "0.0.0.0/0"
    rule_no     = 99
  }

  ingress {
    action = "allow"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_block  = "0.0.0.0/0"
    rule_no     = 100
  }

  egress {
    action = "allow"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_block  = "0.0.0.0/0"
    rule_no     = 100
  }

  tags = {
    Name = "allow_ssh_tls_and_web"
  }

}
####################################

# Creamos los grupos de seguridad para las máquinas que vamos a levantar. Actua a nivel de instancia.
# Del mismo modo que las ACL, los Security Groups serán construidos a partir de estructuras de control sobre objetos de tipo map.

resource "aws_security_group" "allow_web_and_ssh" {
  name        = "allow_web_and_ssh"
  description = "Allow Web and SSH incoming and outgoing traffic."
  vpc_id      = aws_vpc.my_first_vpc.id

  ingress {
    description = "Allow incoming ICMP"
    protocol    = "icmp"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow incoming SSL traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow incoming web traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow incoming SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outgoing traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_tls_and_web"
  }
}
####################################


# Creamos la Elastic IP. No se asocia a ninguna instancia, se hará más adelante en el NAT GW.

resource "aws_eip" "my_first_vpc_eip" {
  vpc      = true
}
####################################

# Creamos el NAT Gateway asociado a la Elastic IP
# La asignación y dependencias del NAT Gateway a las subredes puede realizarse de forma iterativa. Se implementará en el futuro.

resource "aws_nat_gateway" "my_first_vpc_nat_gateway" {
  allocation_id = aws_eip.my_first_vpc_eip.id # Con este recurso se asocia el NAT GW  la EIP.
  subnet_id     = aws_subnet.my_vpc_public_net.id # Forzamos que la NAT GW este en la misma zona que la red pública que hemos definido antes.

  tags = {
    Name = "NAT gateway for VPC ${aws_vpc.my_first_vpc.tags.Name} in zone ${aws_subnet.my_vpc_public_net.availability_zone}"
  }

  depends_on = [ aws_vpc.my_first_vpc, aws_internet_gateway.my_first_vpc_gateway, aws_subnet.my_vpc_public_net, aws_eip.my_first_vpc_eip] # Nos aseguramos que el VPC, el IGW, la subred publica y EIP existan antes de levantar este recurso.
}
####################################

# Definimos las tablas de rutas publicas y privadas. OJO la ruta del VCP está implícita y no hace falta indicarla

resource "aws_route_table" "public_routing_table" {
  vpc_id = aws_vpc.my_first_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_first_vpc_gateway.id
  }

  tags = {
    Name = "Routing table for public vpc ${aws_vpc.my_first_vpc.tags.Name} net"
  }
}

resource "aws_route_table" "private_routing_table" {
  vpc_id = aws_vpc.my_first_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.my_first_vpc_nat_gateway.id # OJO Al vincular la ruta con una NAT GW, la clave debe ser nat_gateway_id, no gateway_id, como el resto de rutas. De lo contratrio
                                                                 # Salta un buug que cambia la ruta cada vez que se hace un apply.
  }

  tags = {
    Name = "Routing table for private vpc ${aws_vpc.my_first_vpc.tags.Name} nets"
  }
}
####################################

# Asociamos las tablas de rutas creadas a las subredes correspondientes
# La asociación de subredes a las tablas de rutas hay que estudiar si se puede hacer de forma iterativa. Se controlará con una propiedad del objeto que se almacene en una estructura de tipo map.

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.my_vpc_public_net.id
  route_table_id = aws_route_table.public_routing_table.id
}

resource "aws_route_table_association" "private_zone_a_association" {
  subnet_id      = aws_subnet.my_first_vpc_net.id
  route_table_id = aws_route_table.private_routing_table.id
}

resource "aws_route_table_association" "private_zone_b_association" {
  subnet_id      = aws_subnet.my_second_vpc_net.id
  route_table_id = aws_route_table.private_routing_table.id
}

resource "aws_route_table_association" "private_zone_c_association" {
  subnet_id      = aws_subnet.my_third_vpc_net.id
  route_table_id = aws_route_table.private_routing_table.id
}
####################################

# Subimos la clave pública que tendrá acceso a las máquinas
# La subida de claves SSH se puede hacer de forma iterativa accediendo a un objeto tipo map.

resource "aws_key_pair" "ssh-vm-igarrido" {
  key_name   = "ssh-vm-igarrido"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDEUESj2yvuspny0YBLevVFPdIL3AzuoItqyawnYoaevLY+I4ytXx2SO9Pvv+ufLguLmYYG5UmigfqYE0R/d2VCnoaw+rLae4hty7CuwrfK0TExCu09GtjURY3BOKpm5Us1f8l2fOS3vxrGvsz5Je9luB7xH6G+HbWdxzzBYhcXvn6DqQXHiuKRPy45oD1hyDiEwdYq720hKxRlwvKHxRk4uVByCNk1k4bVQ7eNugOx8Ldrsxwdj5DTMoU6pVSl2XTpd8qVIqkfh0SLNVrE6uUlmHqSds3ubnDpIBLcd9lDZpZ1LHBeKrj1Vd7KqA4r4bDMkPYwi2wyb2ptoorGODu0OfpM9Jx1g1asmxtPDxHiXHik2SQT4JbOZTQ5LzddtpqQx9G22kxmFs2EXmWAboen+1dmiYYOtQ/TdsrtnFV12kLJ/01jSFD2Cykol35iPC5jl32FDFzW6iWuixI2FnsFtNGDr2YoBNqwVu9UwPXCIEepupxkZ7CULYd2/ckNlS3VspsGHVsVlNONPiU/2YnvexFocJygwC9NCwvadj+zkxH7DLYy2FjbGmvGtQo4CEFj4HESbtECvT7nnyoN3iNwxqhDbbn1MFQn74eOfFrm93cCbdkdhB9mDZEDfxrUegIV+iaOymcApjjc74Lfw7uFi7CqnXCXsj45lDqVk7VYNw== ivan@valhalla"
}
####################################

# Por fin creamos las instancias de prueba. La que esté ubicada en la subred pública (y por tanto zona "a") tendrá comunicación directa con internet través del IGW del VPC. El resto de subredes o zonas tendrán salida hacia internet a través del NAT GW y no serán alcanzables directamente desde internet.
# La declaración de las instancias también se podría hacer de forma iterativa, aunque el objeto que las describirá tiene que tener demasiados atributos, quizás no sea del todo conveniente.

resource "aws_instance" "bastion" {
  ami                          = var.ami
  instance_type                = var.instance_type
  availability_zone            = var.zona_publica # Zona que contiene una red publica
  vpc_security_group_ids       = [aws_security_group.allow_web_and_ssh.id]
  subnet_id                    = aws_subnet.my_vpc_public_net.id # Asociamos la máquina a la red pública, su salida entonces será a través del IGW
  #associate_public_ip_address  = true # La subnet ya asigna IP's públicas por defecto, así que no debería ser necesario habilitar esto.
  key_name                     = aws_key_pair.ssh-vm-igarrido.key_name

  tags = {
    Name = "Bastion"
  }
}

resource "aws_instance" "application1" {
  ami                          = var.ami
  instance_type                = var.instance_type
  availability_zone            = var.zona_privada_c # Zona que contiene una red privada
  vpc_security_group_ids       = [aws_security_group.allow_web_and_ssh.id]
  subnet_id                    = aws_subnet.my_third_vpc_net.id # Asociamos la máquina a la red privada de la zona c, su salida entonces será a través del NAT GW
  #associate_public_ip_address  = false # La subnet no asigna IP's públicas por defecto, así que no debería ser necesario habilitar esto.
  key_name                     = aws_key_pair.ssh-vm-igarrido.key_name

  tags = {
    Name = "app1"
  }
}
####################################

# Declaramos los outputs

output "bastion_ssh_connection" {
  description = "Indica cómo conectarse a la máquina bastion del entorno"
  value = "ssh -A ubuntu@${aws_instance.bastion.public_dns}"
}

output "app1_ssh_connection" {
  description = "Indica cómo conectarse a la máquina interna app 1"
  value = "ssh -A ubuntu@${aws_instance.bastion.private_dns}"
}
